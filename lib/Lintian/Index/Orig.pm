# -*- perl -*- Lintian::Index::Orig
#
# Copyright © 2020 Felix Lechner
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, you can find it on the World Wide
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Index::Orig;

use strict;
use warnings;
use autodie;

use Carp;
use Cwd();
use IO::Async::Loop;
use IO::Async::Process;
use Path::Tiny;

use Lintian::Util qw(get_dsc_info);

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant COLON => q{:};
use constant SLASH => q{/};
use constant NEWLINE => qq{\n};

use Moo;
use namespace::clean;

with 'Lintian::Index';

=encoding utf-8

=head1 NAME

Lintian::Index::Orig -- An index of an upstream (orig) file set

=head1 SYNOPSIS

 use Lintian::Index::Orig;

 # Instantiate via Lintian::Index::Orig
 my $orig = Lintian::Index::Orig->new;

=head1 DESCRIPTION

Instances of this perl class are objects that hold file indices of
upstream file sets. The origins of this class can be found in part
in the collections scripts used previously.

=head1 INSTANCE METHODS

=over 4

=item collect

=item create

=cut

sub collect {
    my ($self, $groupdir) = @_;

    # source packages can be unpacked anywhere; no anchored roots
    $self->allow_empty(1);

    $self->create($groupdir);
    $self->load;

    return;
}

sub create {
    my ($self, $groupdir) = @_;

    my $dsclink = "$groupdir/dsc";
    my $dscpath = Cwd::realpath($dsclink);
    die "Cannot resolve 'dsc' link: $dsclink"
      unless $dscpath;
    die "The 'dsc' link does not point to a file: $dscpath"
      unless -e $dscpath;

    # determine source and version; handles missing fields

    my $dinfo = get_dsc_info($dscpath)
      or croak $dscpath . ' is not valid dsc file';

    my $name = $dinfo->{source} // EMPTY;
    my $version = $dinfo->{version} // EMPTY;
    my $architecture = 'source';

    # it is its own source package
    my $source = $name;
    my $source_version = $version;

    croak $dscpath . ' is missing Source field'
      unless length $name;

    #  Version handling is based on Dpkg::Version::parseversion.
    my $noepoch = $source_version;
    if ($noepoch =~ /:/) {
        $noepoch =~ s/^(?:\d+):(.+)/$1/
          or die "Bad version number '$noepoch'";
    }

    my $baserev = $source . '_' . $noepoch;

    # strip debian revision
    $noepoch =~ s/(.+)-(?:.*)$/$1/;
    my $base = $source . '_' . $noepoch;

    my @files = split(/\n/, $dinfo->{files} // EMPTY);

    my %components;
    for my $line (@files) {

        # strip leading whitespace
        $line =~ s/^\s*//;

        next
          unless length $line;

        # get file name
        my (undef, undef, $name) = split(/\s+/, $line);

        next
          unless length $name;

        # skip if files in subdirs
        next
          if $name =~ m{/};

        # Look for $pkg_$version.orig(-$comp)?.tar.$ext (non-native)
        #       or $pkg_$version.tar.$ext (native)
        #  - This deliberately does not look for the debian packaging
        #    even when this would be a tarball.
        if ($name
            =~ /^(?:\Q$base\E\.orig(?:-(.*))?|\Q$baserev\E)\.tar\.(?:gz|bz2|lzma|xz)$/
        ) {
            $components{$name} = $1 // EMPTY;
        }
    }

    die 'Could not find any source components'
      unless %components;

    my %all;
    for my $tarball (sort keys %components) {

        my $component = $components{$tarball};

        my @tar_options= (
            '--list', '--verbose',
            '--utc', '--full-time',
            '--quoting-style=c','--file'
        );

        # may not be needed; modern tar recognizes lzma and xz
        if ($tarball =~ /\.(lzma|xz)\z/) {
            unshift @tar_options, "--$1";
        }

        my @tar = ('tar', @tar_options, "$groupdir/$tarball");

        my $loop = IO::Async::Loop->new;
        my $future = $loop->new_future;
        my $stdout;
        my $stderr;

        my $process = IO::Async::Process->new(
            command => [@tar],
            stdout => { into => \$stdout },
            stderr => { into => \$stderr },
            on_finish => sub {
                my ($self, $exitcode) = @_;
                my $status = ($exitcode >> 8);

                path("$groupdir/orig-index-errors")->append($stderr // EMPTY);

                if ($status) {
                    my $message
                      = "Non-zero status $status from dpkg-deb for control";
                    $message .= COLON . NEWLINE . $stderr
                      if length $stderr;
                    $future->fail($message);
                    return;
                }

                $future->done('Done with dpkg-deb');
                return;
            });

        $loop->add($process);

        $future->get;

        my @lines = split(/\n/, $stdout);

        my %single;
        for my $line (@lines) {

            my $entry = Lintian::File::Path->new;
            $entry->init_from_tar_output($line);

            $single{$entry->name} = $entry;
        }

        # remove base directory from output
        delete $single{''}
          if exists $single{''};

        my $unwanted = EMPTY;
        for my $name (keys %single) {

            my ($candidate) = ($name =~ m,^([^/]+),);

            unless (length $candidate) {
                $unwanted = EMPTY;
                next;
            }

            if ($candidate eq $name
                && !$single{$name}->perm =~ m/^d/) {
                $unwanted = EMPTY;
                next;
            }

            unless (length $unwanted) {
                $unwanted = $candidate;
                next;
            }

            next
              if $candidate eq $unwanted;

            $unwanted = EMPTY;
        }

        # If there is a common prefix and it is $component, then we use that
        # because that is where they will be extracted by unpacked.
        unless ($unwanted eq $component) {

            my %copy;
            for my $name (keys %single) {

                my $adjusted = $name;

                # strip common prefix
                $adjusted =~ s{^\Q$unwanted\E/+}{}
                  if length $unwanted;

                # add component name
                $adjusted = $component . SLASH . $adjusted
                  if length $component;

                # change name of entry
                $single{$name}->name($adjusted);

                # store entry under new name
                $copy{$adjusted} = $single{$name};
            }

            %single = %copy;
        }

        $all{$_} = $single{$_} for keys %single;
    }

    # treat hard links like regular files
    for my $name (keys %all) {
        my $perm = $all{$name}->perm;
        $perm =~ s/^h/-/;
        $all{$name}->perm($perm);
    }

    $self->catalog(\%all);

    return;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.
Substantial portions adapted from code written by Russ Allbery, Niels Thykier, and others.

=head1 SEE ALSO

lintian(1)

L<Lintian::Index>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

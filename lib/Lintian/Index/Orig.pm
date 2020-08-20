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

use v5.20;
use warnings;
use utf8;
use autodie;

use Cwd();
use IPC::Run3;
use List::MoreUtils qw(uniq);
use Path::Tiny;

use Lintian::Deb822::File;
use Lintian::Index::Item;

use constant EMPTY => q{};
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
    my ($self, $groupdir, $components) = @_;

    # source packages can be unpacked anywhere; no anchored roots
    $self->allow_empty(1);

    $self->create($groupdir, $components);
    $self->load;

    return;
}

sub create {
    my ($self, $groupdir, $components) = @_;

    my %all;
    for my $tarball (sort keys %{$components}) {

        my $component = $components->{$tarball};

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

        my $stdout;
        my $stderr;

        run3(\@tar, undef, \$stdout, \$stderr);

        my $status = ($? >> 8);

        path("$groupdir/orig-index-errors")->append($stderr // EMPTY);

        if ($status) {
            my $message= "Non-zero status $status from @tar";
            $message .= COLON . NEWLINE . $stderr
              if length $stderr;

            die $message;
        }

        my @lines = split(/\n/, $stdout);

        my %single;
        for my $line (@lines) {

            my $entry = Lintian::Index::Item->new;
            $entry->init_from_tar_output($line);

            $single{$entry->name} = $entry;
        }

        # remove base directory from output
        delete $single{''}
          if exists $single{''};

        # unwanted top-level common prefix
        my $unwanted = EMPTY;

        # find all top-level prefixes
        my @prefixes = keys %single;
        s{^([^/]+).*$}{$1}s for @prefixes;

        # squash identical values
        my @unique = uniq @prefixes;

        # check for a single common value
        if (@unique == 1) {
            my $common = $unique[0];

            # use only if there is no directory with that name
            $unwanted = $common
              unless $single{$common} && $single{$common}->perm =~ /^d/;
        }

        # keep common prefix when equal to the source component
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

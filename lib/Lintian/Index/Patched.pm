# -*- perl -*- Lintian::Index::Patched
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

package Lintian::Index::Patched;

use strict;
use warnings;
use autodie;

use IO::Async::Loop;
use IO::Async::Process;
use Path::Tiny;

use Lintian::File::Path;
use Lintian::Util qw(safe_qx);

# Read up to 40kB at the time.  This happens to be 4096 "tar records"
# (with a block-size of 512 and a block factor of 20, which appears to
# be the default).  When we do full reads and writes of READ_SIZE (the
# OS willing), the receiving end will never be with an incomplete
# record.
use constant READ_SIZE => 4096 * 1024 * 10;

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant COLON => q{:};
use constant SLASH => q{/};
use constant NEWLINE => qq{\n};

use Moo;
use namespace::clean;

with 'Lintian::Index',
  'Lintian::Index::FileInfo',
  'Lintian::Index::Java',
  'Lintian::Index::Md5sums';

=encoding utf-8

=head1 NAME

Lintian::Index::Patched -- An index of a patched file set

=head1 SYNOPSIS

 use Lintian::Index::Patched;

 # Instantiate via Lintian::Index::Patched
 my $orig = Lintian::Index::Patched->new;

=head1 DESCRIPTION

Instances of this perl class are objects that hold file indices of
patched file sets. The origins of this class can be found in part
in the collections scripts used previously.

=head1 INSTANCE METHODS

=over 4

=item collect

=item unpack

=cut

sub collect {
    my ($self, @args) = @_;

    my ($pkg, $type, $dir) = @args;

    # source packages can be unpacked anywhere; no anchored roots
    my $basedir = path($dir)->child('unpacked')->stringify;
    $self->basedir($basedir);

    $self->unpack(@args);
    $self->load;

    $self->add_md5sums;
    $self->add_fileinfo;
    $self->add_java;

    return;
}

sub unpack {
    my ($self, $pkg, $type, $dir) = @_;

    my $unpackedpath = "$dir/unpacked/";
    path($unpackedpath)->remove_tree
      if -d $unpackedpath;

    for my $file (qw(index-errors unpacked-errors)) {
        unlink("$dir/$file") if -e "$dir/$file";
    }

    # stop here if we are only asked to remove the files
    return
      if $type =~ m/^remove-/;

    print "N: Using dpkg-source to unpack $pkg\n"
      if $ENV{'LINTIAN_DEBUG'};

    # Ignore STDOUT of the child process because older versions of
    # dpkg-source print things out even with -q.
    my $loop = IO::Async::Loop->new;
    my $future = $loop->new_future;
    my $dpkgerror;

    my $process = IO::Async::Process->new(
        command =>
          ['dpkg-source', '-q','--no-check', '-x',"$dir/dsc", "$dir/unpacked"],
        stderr => { into => \$dpkgerror },
        on_finish => sub {
            my ($self, $exitcode) = @_;
            my $status = ($exitcode >> 8);

            if ($status) {
                my $message = "Non-zero status $status from dpkg-source";
                $message .= COLON . NEWLINE . $dpkgerror
                  if length $dpkgerror;
                $future->fail($message);
                return;
            }

            $future->done('Done with dpkg-deb');
            return;
        });

    $loop->add($process);

    # awaits, and dies with message on failure
    $future->get;

    path("$dir/unpacked-errors")->append($dpkgerror // EMPTY);

    # chdir for index_src
    chdir("$dir/unpacked");

    # get times in UTC
    my $output
      = safe_qx('env', 'TZ=UTC', 'find', '-printf', '%M %s %A+\0%p\0%l\0');

    my $permissionspattern = qr,\S{10},;
    my $sizepattern = qr,\d+,;
    my $datepattern = qr,\d{4}-\d{2}-\d{2},;
    my $timepattern = qr,\d{2}:\d{2}:\d{2}\.\d+,;
    my $pathpattern = qr,[^\0]*,;

    my %all;
    while (
        $output
        =~ s/^($permissionspattern)\ ($sizepattern)\ ($datepattern)\+($timepattern)\0
                  ($pathpattern)\0
                  ($pathpattern)\0//xs
    ) {

        my $entry = Lintian::File::Path->new;

        $entry->perm($1);
        $entry->size($2);
        $entry->date($3);
        $entry->time($4);

        my $name = $5;
        my $linktarget = $6;

        # for non-links, string is empty
        $entry->link($linktarget)
          if length $linktarget;

        # find prints single dot for base; removed in next step
        $name =~ s{^\.$}{\./}s;

        # strip relative prefix
        $name =~ s{^\./+}{}s;

        # make sure directories end with a slash, except root
        $name .= SLASH
          if length $name
          && $entry->perm =~ /^d/
          && substr($name, -1) ne SLASH;
        $entry->name($name);

        $all{$entry->name} = $entry;
    }

    die 'Could not parse output from find command'
      if length $output;

    $self->catalog(\%all);

    # fix permissions
    safe_qx('chmod', '-R', 'u+rwX,o+rX,o-w', "$dir/unpacked");

    # remove error file if empty
    unlink("$dir/unpacked-errors") if -z "$dir/unpacked-errors";

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

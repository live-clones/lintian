# -*- perl -*- Lintian::Index::Md5sums
#
# Copyright © 2020 Felix Lechner
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::Index::Md5sums;

use strict;
use warnings;
use autodie;

use BerkeleyDB;
use IO::Async::Loop;
use IO::Async::Process;
use Path::Tiny;

use Lintian::Util qw(drop_relative_prefix read_md5sums safe_qx);

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant COLON => q{:};
use constant BACKSLASH => q{\\};
use constant NEWLINE => qq{\n};
use constant NULL => qq{\0};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Index::Md5sums - calculate checksums for index.

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Index::Md5sums calculates checksums for an index.

=head1 INSTANCE METHODS

=over 4

=item add_md5sums

=cut

sub add_md5sums {
    my ($self, $pkg, $type, $dir) = @_;

    chdir("$dir/unpacked");

    my $loop = IO::Async::Loop->new;
    my $future = $loop->new_future;

    my @command= ('xargs', '--null', '--no-run-if-empty', 'md5sum', '--');
    my $stdout;
    my $errors;

    my $calculate = IO::Async::Process->new(
        command => [@command],
        stdin => { via => 'pipe_write' },
        stdout => { into => \$stdout },
        stderr => { into => \$errors },
        on_finish => sub {
            my ($self, $exitcode) = @_;
            my $status = ($exitcode >> 8);

            if ($status) {
                my $message = "Command @command exited with status $status";
                $message .= COLON . NEWLINE . $errors
                  if length $errors;
                $future->fail($message);
                return;
            }

            $future->done('Done with @command');
            return;
        });

    $loop->add($calculate);

    # get the regular files in the index
    my @files = grep { $_->is_file } $self->sorted_list;

    # pipe file names to xargs process
    $calculate->stdin->write($_->name . NULL) for @files;

    $calculate->stdin->close_when_empty;
    $future->get;

    my ($md5sums, undef) = read_md5sums($stdout);

    my $dbpath = "$dir/md5sums.db";
    unlink $dbpath
      if -e $dbpath;

    my %h;
    tie %h, 'BerkeleyDB::Btree',
      -Filename => $dbpath,
      -Flags    => DB_CREATE
      or die "Cannot open file $dbpath: $! $BerkeleyDB::Error\n";

    $h{$_} = $md5sums->{$_} for keys %{$md5sums};

    untie %h;

    return;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1), L<Lintian::Collect>, L<Lintian::Collect::Binary>,
L<Lintian::Collect::Source>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

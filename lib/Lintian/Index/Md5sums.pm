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

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Cwd;
use IPC::Run3;
use Unicode::UTF8 qw(encode_utf8 decode_utf8);

use Lintian::Util qw(read_md5sums);

use Moo::Role;
use namespace::clean;

const my $EMPTY => q{};
const my $NULL => qq{\0};

const my $WAIT_STATUS_SHIFT => 8;

=head1 NAME

Lintian::Index::Md5sums - calculate checksums for index.

=head1 SYNOPSIS

    use Lintian::Index;

=head1 DESCRIPTION

Lintian::Index::Md5sums calculates checksums for an index.

=head1 INSTANCE METHODS

=over 4

=item add_md5sums

=cut

sub add_md5sums {
    my ($self) = @_;

    my $savedir = getcwd;
    chdir($self->basedir)
      or die 'Cannot change to directory ' . $self->basedir;

    # get the regular files in the index
    my @files = grep { $_->is_file } @{$self->sorted_list};

    my $input = $EMPTY;
    $input .= $_->name . $NULL for @files;

    my $stdout;
    my $stderr;

    my @command = qw(
      xargs --null --no-run-if-empty
      md5sum --
    );
    run3(\@command, \$input, \$stdout, \$stderr);
    my $status = ($? >> $WAIT_STATUS_SHIFT);

    # allow processing of file names with non UTF-8 bytes
    $stderr = decode_utf8($stderr)
      if length $stderr;

    die encode_utf8("Cannot run @command: $stderr\n")
      if $status;

    my ($md5sums, undef) = read_md5sums($stdout);

    $_->md5sum($md5sums->{$_->name}) for @files;

    chdir($savedir)
      or die "Cannot change to directory $savedir";

    return;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

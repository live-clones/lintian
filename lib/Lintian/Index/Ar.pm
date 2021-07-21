# -*- perl -*- Lintian::Index::Ar
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

package Lintian::Index::Ar;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Cwd;
use Path::Tiny;
use Unicode::UTF8 qw(decode_utf8 encode_utf8);

use Lintian::IPC::Run3 qw(safe_qx);

use Moo::Role;
use namespace::clean;

const my $EMPTY => q{};
const my $NEWLINE => qq{\n};

=head1 NAME

Lintian::Index::Ar - binary symbol information.

=head1 SYNOPSIS

    use Lintian::Index;

=head1 DESCRIPTION

Lintian::Index::Ar binary symbol information.

=head1 INSTANCE METHODS

=over 4

=item add_ar

=cut

sub add_ar {
    my ($self) = @_;

    my $savedir = getcwd;
    chdir($self->basedir)
      or die encode_utf8('Cannot change to directory ' . $self->basedir);

    my $errors = $EMPTY;

    my @archives
      = grep { $_->name =~ / [.]a $/msx && $_->is_regular_file }
      @{$self->sorted_list};

    for my $archive (@archives) {

        # skip empty archives to avoid ar error message; happens in tests
        next
          unless $archive->size;

        my %ar_info;

    # fails silently for non-ar files (#934899); probably creates empty entries
        my $bytes = safe_qx(qw{ar t}, $archive);
        if ($?) {
            $errors .= "ar failed for $archive" . $NEWLINE;
            next;
        }

        my $output = decode_utf8($bytes);
        my @members = split(/\n/, $output);

        my $count = 1;
        for my $member (@members) {

            # more info could be added with -v above
            $ar_info{$count}{name} = $member;

        } continue {
            $count++;
        }

        $archive->ar_info(\%ar_info);
    }

    chdir($savedir)
      or die encode_utf8("Cannot change to directory $savedir");

    return $errors;
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

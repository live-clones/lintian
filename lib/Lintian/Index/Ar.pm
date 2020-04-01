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
use autodie;

use Cwd;
use Path::Tiny;

use Lintian::Util qw(safe_qx);

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant COLON => q{:};
use constant NEWLINE => qq{\n};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Index::Ar - binary symbol information.

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Index::Ar binary symbol information.

=head1 INSTANCE METHODS

=over 4

=item add_ar

=cut

sub add_ar {
    my ($self, $groupdir) = @_;

    my $basket = "$groupdir/ar-info";

    unlink($basket)
      if -e $basket;

    my $savedir = getcwd;
    chdir($self->basedir);

    my @archives;
    foreach my $file ($self->sorted_list) {

        next
          unless $file->is_regular_file && $file =~ m{ \. a \Z }xsm;

        # skip empty archives to avoid ar error message; happens in tests
        next
          unless $file->size;

    # fails silently for non-ar files (#934899); probably creates empty entries
    # in case of trouble, please try: "next if $?;" underneath it
        my $output = safe_qx('ar', 't', $file);
        my @contents = split(/\n/, $output);

        my $line = $file . COLON;
        $line .= SPACE . $_ for @contents;
        push(@archives, $line);
    }

    my $string = EMPTY;
    $string .= $_ . NEWLINE for @archives;
    path($basket)->spew($string);

    chdir($savedir);

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

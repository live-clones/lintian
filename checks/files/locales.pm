# files/locales -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
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

package Lintian::files::locales;

use v5.20;
use warnings;
use utf8;
use autodie;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $LOCALE_CODES = Lintian::Data->new('files/locale-codes', qr/\s++/);
my $INCORRECT_LOCALE_CODES
  = Lintian::Data->new('files/incorrect-locale-codes', qr/\s++/);

sub visit_installed_files {
    my ($self, $file) = @_;

    if (   $file->is_dir
        && $file->name =~ m,^usr/share/locale/([^/]+)/$,) {

        # Without encoding:
        my ($lwccode) = split(m/[.@]/, $1);
        # Without country code:
        my ($lcode) = split(m/_/, $lwccode);

        # special exception:
        if ($lwccode ne 'l10n') {

            if ($INCORRECT_LOCALE_CODES->known($lwccode)) {
                $self->hint('incorrect-locale-code',"$lwccode ->",
                    $INCORRECT_LOCALE_CODES->value($lwccode));

            } elsif ($INCORRECT_LOCALE_CODES->known($lcode)) {
                $self->hint('incorrect-locale-code',"$lcode ->",
                    $INCORRECT_LOCALE_CODES->value($lcode));

            } elsif (!$LOCALE_CODES->known($lcode)) {
                $self->hint('unknown-locale-code', $lcode);

            } elsif ($LOCALE_CODES->known($lcode)
                && defined($LOCALE_CODES->value($lcode))) {
                # If there's a key-value pair in the codes
                # list it means the ISO 639-2 code is being
                # used instead of ISO 639-1's
                $self->hint('incorrect-locale-code', "$lcode ->",
                    $LOCALE_CODES->value($lcode));
            }
        }
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

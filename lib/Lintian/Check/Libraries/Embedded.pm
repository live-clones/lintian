# libraries/embedded -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2012 Kees Cook
# Copyright © 2017-2020 Chris Lamb <lamby@debian.org>
# Copyright © 2021 Felix Lechner
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

package Lintian::Check::Libraries::Embedded;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::Compare;
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SPACE => q{ };

has EMBEDDED_LIBRARIES => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data(
            'binaries/embedded-libs',
            qr/\s*+\|\|/,
            sub {
                my ($label, $details) = @_;

                my ($pairs, $regex) = split(m{\|\|}, $details, 2);

                my %result;
                for my $kvpair (split($SPACE, $pairs)) {

                    my ($key, $value) = split(/=/, $kvpair, 2);
                    $result{$key} = $value;
                }

                my $lc= List::Compare->new([keys %result],
                    [qw{libname source source-regex}]);
                my @unknown = $lc->get_Lonly;

                die encode_utf8(
"Unknown options @unknown for $label (in binaries/embedded-libs)"
                )if @unknown;

                die encode_utf8(
"Both source and source-regex used for $label (in binaries/embedded-libs)"
                )if length $result{source} && length $result{'source-regex'};

                $result{match} = qr/$regex/;

                $result{libname} //= $label;
                $result{source} //= $label;

                return \%result;
            });
    });

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless $item->file_info =~ /^ [^,]* \b ELF \b /x;

    for my $embedded_name ($self->EMBEDDED_LIBRARIES->all) {

        my $library_data = $self->EMBEDDED_LIBRARIES->value($embedded_name);

        next
          if length $library_data->{'source-regex'}
          && $self->processable->source_name=~ $library_data->{'source-regex'};

        next
          if length $library_data->{source}
          && $self->processable->source_name eq $library_data->{source};

        $self->hint('embedded-library', $library_data->{libname},$item->name)
          if $item->strings =~ $library_data->{match};
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

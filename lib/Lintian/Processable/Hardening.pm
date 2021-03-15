# -*- perl -*- Lintian::Processable::Hardening
#
# Copyright © 2019 Felix Lechner
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

package Lintian::Processable::Hardening;

use v5.20;
use warnings;
use utf8;

use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Hardening - access to collected hardening data

=head1 SYNOPSIS

    use Lintian::Processable;

=head1 DESCRIPTION

Lintian::Processable::Hardening provides an interface to collected hardening data.

=head1 INSTANCE METHODS

=over 4

=item hardening_info

Returns a hashref mapping a FILE to its hardening issues.

NB: This is generally only useful for checks/binaries to emit the
hardening-no-* tags.

=cut

sub hardening_info {
    my ($self) = @_;

    return $self->{hardening_info}
      if exists $self->{hardening_info};

    my $hardf = path($self->basedir)->child('hardening-info')->stringify;

    my %hardening_info;

    if (-e $hardf) {
        open(my $idx, '<:utf8_strict', $hardf)
          or die encode_utf8("Cannot open $hardf");

        while (my $line = <$idx>) {
            chomp($line);

            if ($line =~ m{^([^:]+):(?:\./)?(.*)$}) {
                my ($tag, $file) = ($1, $2);

                push(@{$hardening_info{$file}}, $tag);
            }
        }
        close($idx);
    }

    $self->{hardening_info} = \%hardening_info;

    return $self->{hardening_info};
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

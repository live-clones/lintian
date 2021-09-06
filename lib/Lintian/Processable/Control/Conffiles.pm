# -*- perl -*- Lintian::Processable::Control::Conffiles
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

package Lintian::Processable::Control::Conffiles;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Path::Tiny;

use Moo::Role;
use namespace::clean;

const my $SPACE => q{ };
const my $SLASH => q{/};

=head1 NAME

Lintian::Processable::Control::Conffiles - access to collected control data for conffiles

=head1 SYNOPSIS

    use Lintian::Processable;

=head1 DESCRIPTION

Lintian::Processable::Control::Conffiles provides an interface to control data for conffiles.

=head1 INSTANCE METHODS

=over 4

=item conffile_attributes

=cut

has conffile_attributes => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        # read conffiles if it exists and is a file
        my $cf = $self->control->resolve_path('conffiles');
        return {}
          unless $cf && $cf->is_file && $cf->is_open_ok;

        my @lines = path($cf->unpacked_path)->lines_utf8;

        # dpkg strips whitespace (using isspace) from the right hand
        # side of the file name.

        # trim right
        s/\s+$// for @lines;

        my %attributes;

        my @not_empty = grep { length } @lines;
        for my $line (@not_empty) {

            my @words = split($SPACE, $line);
            my $absolute = pop @words;

            # list contains absolute paths, unlike lookup
            $attributes{$absolute} = \@words;
        }

        return \%attributes;
    });

=item conffiles

Returns a list of absolute filenames found for conffiles.

=cut

sub conffiles {
    my ($self) = @_;

    return keys %{$self->conffile_attributes};
}

=item is_conffile (FILE)

Returns a truth value if FILE is listed in the conffiles control file.
If the control file is not present or FILE is not listed in it, it
returns C<undef>.

Note that FILE should be the filename relative to the package root
(even though the control file uses absolute paths).  If the control
file does relative paths, they are assumed to be relative to the
package root as well (and used without warning).

=cut

sub is_conffile {
    my ($self, $file) = @_;

    my $relative = $file;
    $relative =~ s{^/+}{};

    # make sure there is a leading slash
    my $absolute = $SLASH . $relative;

    return 1
      if exists $self->conffile_attributes->{$absolute};

    return 0;
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

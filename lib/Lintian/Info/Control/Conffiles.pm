# -*- perl -*- Lintian::Info::Control::Conffiles
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

package Lintian::Info::Control::Conffiles;

use strict;
use warnings;
use autodie;

use Lintian::Util qw(rstrip);

use constant EMPTY => q{};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Info::Control::Conffiles - access to collected control data for conffiles

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Info::Control::Conffiles provides an interface to control data for conffiles.

=head1 INSTANCE METHODS

=over 4

=item conffiles

Returns a list of absolute filenames found for conffiles.

Needs-Info requirements for using I<conffiles>: L<Same as control_index_resolved_path|/control_index_resolved_path(PATH)>

=cut

sub conffiles {
    my ($self) = @_;

    return @{$self->{'conffiles'}}
      if exists $self->{'conffiles'};

    $self->{'conffiles'} = [];

    # read conffiles if it exists and is a file
    my $cf = $self->control_index_resolved_path('conffiles');
    return
      unless $cf && $cf->is_file && $cf->is_open_ok;

    my $fd = $cf->open;
    while (my $absolute = <$fd>) {

        chomp $absolute;

        # dpkg strips whitespace (using isspace) from the right hand
        # side of the file name.
        rstrip($absolute);

        next
          if $absolute eq EMPTY;

        # list contains absolute paths, unlike lookup
        push(@{$self->{conffiles}}, $absolute);
    }

    close($fd);

    return @{$self->{conffiles}};
}

=item is_conffile (FILE)

Returns a truth value if FILE is listed in the conffiles control file.
If the control file is not present or FILE is not listed in it, it
returns C<undef>.

Note that FILE should be the filename relative to the package root
(even though the control file uses absolute paths).  If the control
file does relative paths, they are assumed to be relative to the
package root as well (and used without warning).

Needs-Info requirements for using I<is_conffile>: L<Same as control_index_resolved_path|/control_index_resolved_path(PATH)>

=cut

sub is_conffile {
    my ($self, $file) = @_;

    unless (exists $self->{'conffiles_lookup'}) {

        $self->{'conffiles_lookup'} = {};

        for my $absolute ($self->conffiles) {

            # strip the leading slash
            my $relative = $absolute;
            $relative =~ s,^/++,,;

            # look up happens with a relative path
            $self->{conffiles_lookup}{$relative} = 1;
        }
    }

    return 1
      if exists $self->{conffiles_lookup}{$file};

    return 0;
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

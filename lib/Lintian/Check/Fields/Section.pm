# fields/section -- lintian check script (rewrite) -*- perl -*-
#
# Copyright © 2004 Marc Brockschmidt
#
# Parts of the code were taken from the old check script, which
# was Copyright © 1998 Richard Braakman (also licensed under the
# GPL 2 or higher)
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

package Lintian::Check::Fields::Section;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

our %KNOWN_ARCHIVE_PARTS = map { $_ => 1 } qw(non-free contrib);

sub udeb {
    my ($self) = @_;

    my $section = $self->processable->fields->unfolded_value('Section');

    $self->hint('wrong-section-for-udeb', $section)
      unless $section eq 'debian-installer';

    return;
}

sub always {
    my ($self) = @_;

    my $pkg = $self->processable->name;

    return
      unless $self->processable->fields->declares('Section');

    my $KNOWN_SECTIONS = $self->profile->load_data('fields/archive-sections');

    # Mapping of package names to section names
    my $NAME_SECTION_MAPPINGS = $self->profile->load_data(
        'fields/name_section_mappings',
        qr/\s*=>\s*/,
        sub {
            return {'regex' =>  qr/$_[0]/x, 'section' => $_[1]};
        });

    my $section = $self->processable->fields->unfolded_value('Section');

    return
      if $self->processable->type eq 'udeb';

    my @parts = split(m{/}, $section, 2);

    my $division;
    $division = $parts[0]
      if @parts > 1;

    my $fraction = $parts[-1];

    if (defined $division) {
        $self->hint('unknown-section', $section)
          unless $KNOWN_ARCHIVE_PARTS{$division};
    }

    if ($fraction eq 'unknown' && !length $division) {
        $self->hint('section-is-dh_make-template');
    } else {
        $self->hint('unknown-section', $section)
          unless $KNOWN_SECTIONS->recognizes($fraction);
    }

    # Check package name <-> section.  oldlibs is a special case; let
    # anything go there.
    if ($fraction ne 'oldlibs') {

        foreach my $name_section ($NAME_SECTION_MAPPINGS->all()) {
            my $regex= $NAME_SECTION_MAPPINGS->value($name_section)->{'regex'};
            my $want
              = $NAME_SECTION_MAPPINGS->value($name_section)->{'section'};

            next
              unless ($pkg =~ m{$regex});

            unless ($fraction eq $want) {

                my $better
                  = (defined $division ? "$division/" : $EMPTY) . $want;
                $self->hint('wrong-section-according-to-package-name',
                    "$pkg => $better");
            }

            last;
        }
    }

    if ($fraction eq 'debug') {

        $self->hint('wrong-section-according-to-package-name',"$pkg")
          if $pkg !~ /-dbg(?:sym)?$/;
    }

    if ($self->processable->is_transitional) {

        my $priority = $self->processable->fields->unfolded_value('Priority');

        $self->hint('transitional-package-not-oldlibs-optional',
            "$fraction/$priority")
          unless $priority eq 'optional' && $fraction eq 'oldlibs';
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

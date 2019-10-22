# fields/section -- lintian check script (rewrite) -*- perl -*-
#
# Copyright (C) 2004 Marc Brockschmidt
#
# Parts of the code were taken from the old check script, which
# was Copyright (C) 1998 Richard Braakman (also licensed under the
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

package Lintian::fields::section;

use strict;
use warnings;
use autodie;

use Moo;

use Lintian::Data ();

with('Lintian::Check');

use constant EMPTY => q{};

our $KNOWN_SECTIONS = Lintian::Data->new('fields/archive-sections');

# Mapping of package names to section names
my $NAME_SECTION_MAPPINGS = Lintian::Data->new(
    'fields/name_section_mappings',
    qr/\s*=>\s*/,
    sub {
        return {'regex' =>  qr/$_[0]/x, 'section' => $_[1]};
    });

our %KNOWN_ARCHIVE_PARTS = map { $_ => 1 } ('non-free', 'contrib');

sub binary {
    my ($self) = @_;

    my $info = $self->info;

    my $section = $info->unfolded_field('section');

    unless (defined $section) {
        $self->tag('no-section-field');
        return;
    }

    return;
}

sub udeb {
    my ($self) = @_;

    my $info = $self->info;

    my $section = $info->unfolded_field('section');

    return
      unless defined $section;

    $self->tag('wrong-section-for-udeb', $section)
      unless $section eq 'debian-installer';

    return;
}

sub always {
    my ($self) = @_;

    my $pkg = $self->package;
    my $type = $self->type;
    my $info = $self->info;

    my $section = $info->unfolded_field('section');

    return
      unless defined $section;

    if ($section eq EMPTY) {
        $self->tag('empty-section-field');
        return;
    }

    return
      if $type eq 'udeb';

    my @parts = split(m{/}, $section, 2);

    my $division;
    $division = $parts[0]
      if @parts > 1;

    my $fraction = $parts[-1];

    if (defined $division) {
        $self->tag('unknown-section', $section)
          unless $KNOWN_ARCHIVE_PARTS{$division};
    }

    if ($fraction eq 'unknown' && !length $division) {
        $self->tag('section-is-dh_make-template');
    } else {
        $self->tag('unknown-section', $section)
          unless $KNOWN_SECTIONS->known($fraction);
    }

    # Check package name <-> section.  oldlibs is a special case; let
    # anything go there.
    if ($fraction ne 'oldlibs') {

        foreach my $name_section ($NAME_SECTION_MAPPINGS->all()) {
            my $regex= $NAME_SECTION_MAPPINGS->value($name_section)->{'regex'};
            my $section
              = $NAME_SECTION_MAPPINGS->value($name_section)->{'section'};

            next
              unless ($pkg =~ m{$regex});

            unless ($fraction eq $section) {

                my $better
                  = (defined $division ? "$division/" : EMPTY) . $section;
                $self->tag('wrong-section-according-to-package-name',
                    "$pkg => $better");
            }

            last;
        }
    }

    if ($fraction eq 'debug') {

        $self->tag('wrong-section-according-to-package-name',"$pkg")
          if $pkg !~ /-dbg(?:sym)?$/;
    }

    if ($info->is_pkg_class('transitional')) {

        my $priority = $info->unfolded_field('priority') // EMPTY;

        $self->tag('transitional-package-should-be-oldlibs-optional',
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

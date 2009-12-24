# Copyright © 2008 Frank Lichtenheld <frank@lichtenheld.de>
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

package Lintian::Output::XML;

use strict;
use warnings;

use HTML::Entities;

use Lintian::Output qw(:util);
use base qw(Lintian::Output);

sub print_tag {
    my ($self, $pkg_info, $tag_info, $information, $overridden) = @_;
    $self->issued_tag($tag_info->tag);
    my $flags = ($tag_info->experimental ? 'experimental' : '');
    if ($overridden) {
        $flags .= ',' if $flags;
        $flags .= 'overridden';
    }
    my @attrs = ([ severity  => $tag_info->severity ],
                 [ certainty => $tag_info->certainty ],
                 [ flags     => $flags ],
                 [ name      => $tag_info->tag ]);
    $self->_print_xml_tag('tag', \@attrs, $information);
}

sub print_start_pkg {
    my ($self, $pkg_info) = @_;
    my @attrs = ([ type         => $pkg_info->{type} ],
                 [ name         => $pkg_info->{package} ],
                 [ architecture => $pkg_info->{arch} ],
                 [ version      => $pkg_info->{version} ]);
    $self->_print_xml_tag('package', \@attrs);
}

sub print_end_pkg {
    my ($self) = @_;
    print { $self->stdout } "</package>\n"
}

sub _delimiter {
    return;
}

sub _print {
    my ($self, $stream, $lead, @args) = @_;
    $stream ||= $self->stderr;
    my $output = $self->string($lead, @args);
    print { $stream } $output;
}

# Print a given XML tag to standard output.  Takes the tag, an anonymous array
# of pairs of attributes and values, and then the contents of the tag.
sub _print_xml_tag {
    my ($self, $tag, $attrs, $content) = @_;
    my $output = "<$tag";
    for my $attr (@$attrs) {
        my ($name, $value) = @$attr;
        $output .= " $name=" . '"' . $value . '"';
    }
    $output .= '>';
    if (defined $content) {
        $output .= encode_entities($content,"<>&\"'") . "</$tag>";
    }
    print { $self->stdout } $output, "\n";
}

1;

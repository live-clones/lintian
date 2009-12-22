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
    $self->_print_xml('',
		      qq{<tag severity="}, $tag_info->severity, qq{" certainty="}, $tag_info->certainty, qq{"},
		      'flags="'.($tag_info->experimental ? 'experimental' : ''),
		      ($overridden ? 'overridden' : '').'"',
		      qq{name="}, $tag_info->tag, qq{">}.encode_entities("$information","<>&\"'").qq{</tag>},
	);
}

sub print_start_pkg {
    my ($self, $pkg_info) = @_;

    $self->_print_xml('',
		      qq{<package type="$pkg_info->{type}" name="$pkg_info->{package}"},
		      qq{architecture="$pkg_info->{arch}" version="$pkg_info->{version}">}
	);
}

sub print_end_pkg {
    my ($self) = @_;
    $self->_print_xml('', '</package>');
}

sub _delimiter {
    return;
}

sub _print {
    my ($self, $stream, $lead, @args) = @_;
    $stream ||= $self->stderr;

    my $output = $self->string($lead, @args);
    print {$stream} $output;
}

sub _print_xml {
    my ($self, $stream, @args) = @_;
    $stream ||= $self->stdout;

    print {$stream} join(' ',@args), "\n";
}

1;


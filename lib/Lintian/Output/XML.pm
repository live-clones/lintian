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

use Moo;
use namespace::clean;

with 'Lintian::Output';

=head1 NAME

Lintian::Output::XML - XML tag output

=head1 SYNOPSIS

    use Lintian::Output::XML;

=head1 DESCRIPTION

Provides XML tag output.

=head1 INSTANCE METHODS

=over 4

=item print_tag

=cut

sub print_tag {
    my ($self, $tag) = @_;

    my $tag_info = $tag->info;
    my $information = $tag->extra;
    my $override = $tag->override;

    $self->issued_tag($tag_info->tag);
    my $flags = ($tag_info->experimental ? 'experimental' : '');
    my $comment;
    if ($override) {
        $flags .= ',' if $flags;
        $flags .= 'overridden';
        if (@{ $override->{comments} }) {
            my $c = $self->_make_xml_tag('comment', [],
                join("\n", @{ $override->{comments} }));
            $comment = [$c];
        }
    }
    my @attrs = (
        [severity  => $tag_info->severity],
        [certainty => $tag_info->certainty],
        [flags     => $flags],
        [name      => $tag_info->tag]);
    print { $self->stdout }
      $self->_make_xml_tag('tag', \@attrs, $self->_quote_print($information),
        $comment),
      "\n";
    return;
}

=item print_start_pkg

=cut

sub print_start_pkg {
    my ($self, $processable) = @_;
    my @attrs = (
        [type         => $processable->type],
        [name         => $processable->name],
        [architecture => $processable->pkg_arch],
        [version      => $processable->pkg_version]);
    print { $self->stdout } $self->_open_xml_tag('package', \@attrs, 0), "\n";
    return;
}

=item print_end_pkg

=cut

sub print_end_pkg {
    my ($self) = @_;
    print { $self->stdout } "</package>\n";
    return;
}

sub _delimiter {
    return;
}

sub _print {
    my ($self, $stream, $lead, @args) = @_;
    $stream ||= $self->stderr;
    my $output = $self->string($lead, @args);
    print {$stream} $output;
    return;
}

# Create a start tag (or a self-closed tag)
# $tag is the name of the tag
# $attrs is an anonymous array of pairs of attributes and their values
# $close is a boolean.  If a truth-value, the tag will closed
#
# returns the string.
sub _open_xml_tag {
    my ($self, $tag, $attrs, $close) = @_;
    my $output = "<$tag";
    for my $attr (@$attrs) {
        my ($name, $value) = @$attr;
        # Skip attributes with "empty" values
        next unless defined $value && $value ne '';
        $output .= " $name=" . '"' . $value . '"';
    }
    $output .= ' /' if $close;
    $output .= '>';
    return $output;
}

# Print a given XML tag to standard output.  Takes the tag, an anonymous array
# of pairs of attributes and values, and then the contents of the tag.
sub _make_xml_tag {
    my ($self, $tag, $attrs, $content, $children) = @_;
    # $empty is true if $content is empty and there are no children
    my $empty = ($content//'') eq '' && (!defined $children || !@$children);
    my $output = $self->_open_xml_tag($tag, $attrs, $empty);
    if (!$empty) {
        $output .= encode_entities($content, q{<>&"'}) if $content;
        if (defined $children) {
            foreach my $child (@$children) {
                $output .= "\n\t$child";
            }
            $output .= "\n";
        }
        $output .= "</$tag>";
    }
    return $output;
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

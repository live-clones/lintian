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

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant NEWLINE => qq{\n};

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

=item issue_tags

Print all tags passed in array. A separate arguments with processables
is necessary to report in case no tags were found.

=cut

my %code_priority = (
    'E' => 30,
    'W' => 40,
    'I' => 50,
    'P' => 60,
    'X' => 70,
    'O' => 80,
);

my %type_priority = (
    'source' => 30,
    'binary' => 40,
    'udeb' => 50,
    'changes' => 60,
    'buildinfo' => 70,
);

sub issue_tags {
    my ($self, $pending, $processables) = @_;

    return
      unless $pending && $processables;

    my %taglist;

    for my $tag (@{$pending}) {
        $taglist{$tag->processable} //= [];
        push(@{$taglist{$tag->processable}}, $tag);
    }

    my @ordered = sort {
             $type_priority{$a->type} <=> $type_priority{$b->type}
          || $a->name cmp $b->name
    } @{$processables};

    for my $processable (@ordered) {

        my @attrs = (
            [type         => $processable->type],
            [name         => $processable->name],
            [architecture => $processable->architecture],
            [version      => $processable->version]);

        my $preamble = $self->_open_xml_tag('package', \@attrs, 0);
        print { $self->stdout } $preamble, NEWLINE;

        my @sorted = sort {
            $code_priority{$a->info->code} <=> $code_priority{$b->info->code}
              || $a->name cmp $b->name
              || $a->extra cmp $b->extra
        } @{$taglist{$processable} // []};

        $self->print_tag($_) for @sorted;

        print { $self->stdout } "</package>\n";
    }

    return;
}

=item print_tag

=cut

sub print_tag {
    my ($self, $tag) = @_;

    my $tag_info = $tag->info;
    my $information = $tag->extra;
    my $override = $tag->override;

    $self->issuedtags->{$tag_info->tag}++;

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

=item C<_quote_print($string)>

Called to quote a string.  By default it will replace all
non-printables with "?".  Sub-classes can override it if
they allow non-ascii printables etc.

=cut

sub _quote_print {
    my ($self, $string) = @_;
    $string =~ s/[^[:print:]]/?/go;
    return $string;
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

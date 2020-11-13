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

package Lintian::Output::EWI;

use v5.20;
use warnings;
use utf8;

use HTML::HTML5::Entities;
use Term::ANSIColor ();
use Text::Wrap;

# for tty hyperlinks
use constant OSC_HYPERLINK => qq{\033]8;;};
use constant OSC_DONE => qq{\033\\};

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant COLON => q{:};
use constant NEWLINE => qq{\n};

use Moo;
use namespace::clean;

with 'Lintian::Output';

=head1 NAME

Lintian::Output::EWI - standard tag output

=head1 SYNOPSIS

    use Lintian::Output::EWI;

=head1 DESCRIPTION

Provides standard tag output.

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
    'C' => 80,
    'O' => 90,
);

my %type_priority = (
    'source' => 30,
    'binary' => 40,
    'udeb' => 50,
    'changes' => 60,
    'buildinfo' => 70,
);

sub issue_tags {
    my ($self, $groups) = @_;

    my @processables = map { $_->get_processables } @{$groups // []};

    my @pending;
    for my $processable (@processables) {

        # get tags
        my @tags = @{$processable->tags};

        # associate tags with processable
        $_->processable($processable) for @tags;

        # remove circular references
        $processable->tags([]);

        push(@pending, @tags);
    }

    my @sorted = sort {
             defined $a->override <=> defined $b->override
          || $code_priority{$a->info->code} <=> $code_priority{$b->info->code}
          || $a->name cmp $b->name
          || $type_priority{$a->processable->type}
          <=> $type_priority{$b->processable->type}
          || $a->processable->name cmp $b->processable->name
          || $a->context cmp $b->context
    } @pending;

    $self->print_tag($_) for @sorted;

    return;
}

=item C<print_tag($pkg_info, $tag_info, $context, $override)>

Print a tag.  The first two arguments are hash reference with the
information about the package and the tag, $context is the context
information for the tag (if any) as an array reference, and $override
is either undef if the tag is not overridden or a hash with
override info for this tag.

=cut

sub print_tag {
    my ($self, $tag) = @_;

    my $tag_info = $tag->info;
    my $tag_name = $tag_info->name;

    my $information = $tag->context;
    $information = SPACE . $self->_quote_print($information)
      unless $information eq EMPTY;

    # Limit the output so people do not drown in tags.  Some tags are
    # insanely noisy (hi static-library-has-unneeded-section)
    my $limit = $self->tag_display_limit;
    if ($limit) {

        my $proc_id = $tag->processable->identifier;
        my $emitted_count= $self->proc_id2tag_count->{$proc_id}{$tag_name}++;

        return
          if $emitted_count >= $limit;

        my $msg
          = ' ... use --no-tag-display-limit to see all (or pipe to a file/program)';
        $information = $self->_quote_print($msg)
          if $emitted_count >= $limit-1;
    }

    my $text = $tag_name;

    my $code = $tag_info->code;
    $code = 'O' if defined $tag->override;

    my $tag_color = $self->{colors}{$code};

    # keep original color for tags marked experimental
    $code = 'X' if $tag_info->experimental;

    $text = Term::ANSIColor::colored($tag_name, $tag_color)
      if $self->color;

    my $output;
    if ($self->tty_hyperlinks && $self->color) {
        my $target= 'https://lintian.debian.org/tags/' . $tag_name . '.html';
        $output .= $self->osc_hyperlink($text, $target);
    } else {
        $output .= $text;
    }

    my $override = $tag->override;
    if ($override && @{ $override->{comments} }) {

        $self->msg($self->_quote_print($_))for @{ $override->{comments} };
    }

    my $type = EMPTY;
    $type = SPACE . $tag->processable->type
      unless $tag->processable->type eq 'binary';

    say $code
      . COLON
      . SPACE
      . $tag->processable->name
      . $type
      . COLON
      . SPACE
      . $output
      . $information;

    $self->describe_tags($tag_info)
      if $self->showdescription && !$self->issued_tag($tag_info->name);

    return;
}

=item C<_quote_print($string)>

Called to quote a string.  By default it will replace all
non-printables with "?".  Sub-classes can override it if
they allow non-ascii printables etc.

=cut

sub _quote_print {
    my ($self, $string) = @_;

    $string =~ s/[^[:print:]]/?/g;

    return $string;
}

=item C<osc_hyperlink>

=cut

sub osc_hyperlink {
    my ($self, $text, $target) = @_;

    my $start = OSC_HYPERLINK . $target . OSC_DONE;
    my $end = OSC_HYPERLINK . OSC_DONE;

    return $start . $text . $end;
}

=item issuedtags

Hash containing the names of tags which have been issued.

=cut

has issuedtags => (is => 'rw', default => sub { {} });

=item C<issued_tag($tag_name)>

Indicate that the named tag has been issued.  Returns a boolean value
indicating whether the tag had previously been issued by the object.

=cut

sub issued_tag {
    my ($self, $tag_name) = @_;

    return $self->issuedtags->{$tag_name}++ ? 1 : 0;
}

=item describe_tags

=cut

sub describe_tags {
    my ($self, @tag_infos) = @_;

    for my $tag_info (@tag_infos) {
        my $code = 'N';
        my $description = 'N:   Unknown tag.';

        if (defined $tag_info) {

            $code = $tag_info->code;

            my $plain_text= markdown_to_plain($tag_info->markdown_description);
            $description = indent_and_wrap($plain_text, 'N:   ');

            chomp $description;
        }

        my $output = 'N:' . NEWLINE;
        $output .= $code . COLON . SPACE . $tag_info->name . NEWLINE;
        $output .= 'N:' . NEWLINE;
        $output .= $description . NEWLINE;
        $output .= 'N:' . NEWLINE;

        print $output;
    }

    return;
}

=item indent_and_wrap

=cut

sub indent_and_wrap {
    my ($text, $indent) = @_;

    my @paragraphs = split(/\n{2,}/, $text);

    my @indented;
    for my $paragraph (@paragraphs) {

        if ($paragraph =~ /^\s/) {

            # do not wrap preformatted lines; indent only
            my @lines = split(/\n/, $paragraph);
            my $indented_paragraph= join(NEWLINE, map { $indent . $_ } @lines);

            push(@indented, $indented_paragraph);

        } else {
            # reduce whitespace throughout, including newlines
            $paragraph =~ s/\s+/ /g;

            # trim beginning and end of each line
            $paragraph =~ s/^\s+|\s+$//mg;

            # do not wrap long words like urls, see #719769
            local $Text::Wrap::huge = 'overflow';

            my $wrapped_paragraph = wrap($indent, $indent, $paragraph);

            push(@indented, $wrapped_paragraph);
        }
    }

    my $formatted = join(NEWLINE . $indent . NEWLINE, @indented) . NEWLINE;

    return $formatted;
}

=item markdown_to_plain

=cut

sub markdown_to_plain {
    my ($markdown) = @_;

    # use angular brackets for emphasis
    $markdown =~ s{<i>|<em>}{&lt;}g;
    $markdown =~ s{</i>|</em>}{&gt;}g;

    # drop Markdown hyperlinks
    $markdown =~ s{\[([^\]]+)\]\([^\)]+\)}{$1}g;

    # drop all HTML tags except Markdown shorthand <$url>
    $markdown =~ s{<(?![a-z]+://)[^>]+>}{}g;

    # drop brackets around Markdown shorthand <$url>
    $markdown =~ s{<([a-z]+://[^>]+)>}{$1}g;

    # substitute HTML entities
    my $plain = decode_entities($markdown);

    return $plain;
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

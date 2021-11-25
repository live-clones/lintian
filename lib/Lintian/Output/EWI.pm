# Copyright © 2008 Frank Lichtenheld <frank@lichtenheld.de>
# Copyright © 2021 Felix Lechner
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

use Const::Fast;
use HTML::HTML5::Entities;
use List::Compare;
use Term::ANSIColor ();
use Text::Wrap;
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Output::Grammar';

# for tty hyperlinks
const my $OSC_HYPERLINK => qq{\033]8;;};
const my $OSC_DONE => qq{\033\\};
const my $BEL => qq{\a};

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $COLON => q{:};
const my $DOT => q{.};
const my $NEWLINE => qq{\n};
const my $PARAGRAPH_BREAK => $NEWLINE x 2;

const my $YES => q{yes};
const my $NO => q{no};

const my $COMMENT_PREFIX => q{N:} . $SPACE;

const my $DESCRIPTION_INDENTATION => 2;
const my $DESCRIPTION_PREFIX => $COMMENT_PREFIX
  . $SPACE x $DESCRIPTION_INDENTATION;

const my $SCREEN_INDENTATION => 4;
const my $SCREEN_PREFIX => $COMMENT_PREFIX . $SPACE x $SCREEN_INDENTATION;

const my %COLORS => (
    'E' => 'red',
    'W' => 'yellow',
    'I' => 'cyan',
    'P' => 'green',
    'C' => 'blue',
    'O' => 'bright_black',
    'M' => 'bright_black',
);

const my %CODE_PRIORITY => (
    'E' => 30,
    'W' => 40,
    'I' => 50,
    'P' => 60,
    'X' => 70,
    'C' => 80,
    'O' => 90,
    'M' => 100,
);

const my %TYPE_PRIORITY => (
    'source' => 30,
    'binary' => 40,
    'udeb' => 50,
    'changes' => 60,
    'buildinfo' => 70,
);

=head1 NAME

Lintian::Output::EWI - standard hint output

=head1 SYNOPSIS

    use Lintian::Output::EWI;

=head1 DESCRIPTION

Provides standard hint output.

=head1 INSTANCE METHODS

=over 4

=item tag_count_by_processable

=cut

has tag_count_by_processable => (is => 'rw', default => sub { {} });

=item issue_hints

=cut

sub issue_hints {
    my ($self, $groups, $option) = @_;

    my %sorter;
    for my $group (@{$groups // []}) {

        for my $processable ($group->get_processables) {

            my $type = $processable->type;
            my $type_priority = $TYPE_PRIORITY{$type};

            for my $hint (@{$processable->hints}) {

                my $tag = $hint->tag;
                my $override_status = defined $hint->override;
                my $code_priority = $CODE_PRIORITY{$tag->code};

                my %for_output;
                $for_output{hint} = $hint;
                $for_output{processable} = $processable;

                push(
                    @{
                        $sorter{$override_status}{$code_priority}{$tag->name}
                          {$type_priority}{$processable->name}{$hint->context}
                    },
                    \%for_output
                );
            }
        }
    }

    for my $override_status (sort keys %sorter) {

        my %by_code_priority = %{$sorter{$override_status}};

        for my $code_priority (sort { $a <=> $b } keys %by_code_priority) {

            my %by_tag_name = %{$by_code_priority{$code_priority}};

            for my $tag_name (sort keys %by_tag_name) {

                my %by_type_priority = %{$by_tag_name{$tag_name}};

                for
                  my $type_priority (sort { $a <=> $b }keys %by_type_priority){

                    my %by_processable_name
                      = %{$by_type_priority{$type_priority}};

                    for my $processable_name (sort keys %by_processable_name) {

                        my %by_context
                          = %{$by_processable_name{$processable_name}};

                        for my $context (sort keys %by_context) {

                            my $for_output
                              = $sorter{$override_status}{$code_priority}
                              {$tag_name}{$type_priority}{$processable_name}
                              {$context};

                            for my $each (@{$for_output}) {

                                my $hint = $each->{hint};
                                my $processable = $each->{processable};

                                $self->print_hint($hint, $processable,$option);
                            }
                        }
                    }
                }
            }
        }
    }

    return;
}

=item C<print_hint>

=cut

sub print_hint {
    my ($self, $hint, $processable, $option) = @_;

    my $tag = $hint->tag;
    my $tag_name = $tag->name;

    my @want_references = @{$option->{'display-source'} // []};
    my @have_references = @{$tag->see_also};

    # keep only the first word
    s{^ ([\w-]+) \s }{$1}x for @have_references;

    # drop anything in parentheses at the end
    s{ [(] \S+ [)] $}{}x for @have_references;

    # check if hint refers to the selected references
    my $reference_lc= List::Compare->new(\@have_references, \@want_references);

    my @found_references = $reference_lc->get_intersection;

    return
      if @want_references
      && !@found_references;

    my $information = $hint->context;
    $information = $SPACE . $self->_quote_print($information)
      unless $information eq $EMPTY;

    # Limit the output so people do not drown in hints.  Some hints are
    # insanely noisy (hi static-library-has-unneeded-section)
    my $limit = $option->{'tag-display-limit'};
    if ($limit) {

        my $processable_id = $processable->identifier;
        my $emitted_count
          = $self->tag_count_by_processable->{$processable_id}{$tag_name}++;

        return
          if $emitted_count >= $limit;

        my $msg
          = ' ... use --no-tag-display-limit to see all (or pipe to a file/program)';
        $information = $self->_quote_print($msg)
          if $emitted_count >= $limit-1;
    }

    say encode_utf8('N:')
      if $option->{info};

    my $text = $tag_name;

    my $code = $tag->code;
    $code = 'O' if defined $hint->override;
    $code = 'M' if defined $hint->screen;

    my $tag_color = $COLORS{$code};

    # keep original color for tags marked experimental
    $code = 'X' if $tag->experimental;

    $text = Term::ANSIColor::colored($tag_name, $tag_color)
      if $option->{color};

    my $output;
    if ($option->{hyperlinks} && $option->{color}) {
        my $target= 'https://lintian.debian.org/tags/' . $tag_name;
        $output .= $self->osc_hyperlink($text, $target);
    } else {
        $output .= $text;
    }

    if ($hint->override) {
        say encode_utf8('N: ' . $self->_quote_print($_))
          for @{$hint->override->{comments}};
    }

    say encode_utf8('N: masked by screen ' . $hint->screen->name)
      if defined $hint->screen;

    my $type = $EMPTY;
    $type = $SPACE . $processable->type
      unless $processable->type eq 'binary';

    say encode_utf8($code
          . $COLON
          . $SPACE
          . $processable->name
          . $type
          . $COLON
          . $SPACE
          . $output
          . $information);

    if ($option->{info}) {

        $self->describe_tag($tag, $option->{'output-width'})
          unless $self->issued_tag($tag->name);
    }

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

    my $start = $OSC_HYPERLINK . $target . $BEL;
    my $end = $OSC_HYPERLINK . $BEL;

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
    my ($self, $tags, $columns) = @_;

    for my $tag (@{$tags}) {

        my $name;
        my $code;

        if (defined $tag) {
            $name = $tag->name;
            $code = $tag->code;

        } else {
            $name = 'unknown-tag';
            $code = 'N';
        }

        say encode_utf8('N:');
        say encode_utf8("$code: $name");

        $self->describe_tag($tag, $columns);
    }

    return;
}

=item describe_tag

=cut

sub describe_tag {
    my ($self, $tag, $columns) = @_;

    local $Text::Wrap::columns = $columns;

    # do not wrap long words such as urls; see #719769
    local $Text::Wrap::huge = 'overflow';

    my $wrapped = $COMMENT_PREFIX . $NEWLINE;

    if (defined $tag) {

        my $plain_explanation = markdown_to_plain($tag->explanation,
            $columns - length $DESCRIPTION_PREFIX);

        $wrapped .= $DESCRIPTION_PREFIX . $_ . $NEWLINE
          for split(/\n/, $plain_explanation);

        if (@{$tag->see_also}) {

            $wrapped .= $COMMENT_PREFIX . $NEWLINE;

            my $markdown
              = 'Please refer to '
              . $self->oxford_enumeration('and', @{$tag->see_also})
              . ' for details.'
              . $NEWLINE;
            my $plain = markdown_to_plain($markdown,
                $columns - length $DESCRIPTION_PREFIX);

            $wrapped .= $DESCRIPTION_PREFIX . $_ . $NEWLINE
              for split(/\n/, $plain);
        }

        $wrapped .= $COMMENT_PREFIX . $NEWLINE;

        my $visibility_prefix = 'Visibility: ';
        $wrapped.= wrap(
            $DESCRIPTION_PREFIX . $visibility_prefix,
            $DESCRIPTION_PREFIX . $SPACE x length $visibility_prefix,
            $tag->visibility . $NEWLINE
        );

        $wrapped .= wrap($DESCRIPTION_PREFIX, $DESCRIPTION_PREFIX,
            'Show-Always: '. ($tag->show_always ? $YES : $NO) . $NEWLINE);

        my $check_prefix = 'Check: ';
        $wrapped .= wrap(
            $DESCRIPTION_PREFIX . $check_prefix,
            $DESCRIPTION_PREFIX . $SPACE x length $check_prefix,
            $tag->check . $NEWLINE
        );

        if (@{$tag->renamed_from}) {

            $wrapped .= wrap($DESCRIPTION_PREFIX, $DESCRIPTION_PREFIX,
                    'Renamed from: '
                  . join($SPACE, @{$tag->renamed_from})
                  . $NEWLINE);
        }

        $wrapped
          .= wrap($DESCRIPTION_PREFIX, $DESCRIPTION_PREFIX,
            'This tag is experimental.' . $NEWLINE)
          if $tag->experimental;

        $wrapped .= wrap($DESCRIPTION_PREFIX, $DESCRIPTION_PREFIX,
            'This tag is a classification. There is no issue in your package.'
              . $NEWLINE)
          if $tag->visibility eq 'classification';

        for my $screen (@{$tag->screens}) {

            $wrapped .= $COMMENT_PREFIX . $NEWLINE;

            $wrapped
              .= wrap($DESCRIPTION_PREFIX, $DESCRIPTION_PREFIX,
                'Screen: ' . $screen->name . $NEWLINE);

            $wrapped .= wrap($SCREEN_PREFIX, $SCREEN_PREFIX,
                'Advocates: '. join(', ', @{$screen->advocates}). $NEWLINE);

            my $combined = $screen->reason . $NEWLINE;
            if (@{$screen->see_also}) {
                $combined .= $NEWLINE;
                $combined
                  .= 'Read more in '
                  . $self->oxford_enumeration('and', @{$tag->see_also})
                  . $DOT
                  . $NEWLINE;
            }

            my $reason_prefix = 'Reason: ';
            my $plain = markdown_to_plain($combined,
                $columns - length($SCREEN_PREFIX . $reason_prefix));

            my @lines = split(/\n/, $plain);
            $wrapped
              .= $SCREEN_PREFIX . $reason_prefix . (shift @lines) . $NEWLINE;
            $wrapped
              .= $SCREEN_PREFIX
              . $SPACE x (length $reason_prefix)
              . $_
              . $NEWLINE
              for @lines;
        }

    } else {
        $wrapped
          .= wrap($DESCRIPTION_PREFIX, $DESCRIPTION_PREFIX, 'Unknown tag.');
    }

    $wrapped .= $COMMENT_PREFIX . $NEWLINE;

    print encode_utf8($wrapped);

    return;
}

=item markdown_to_plain

=cut

sub markdown_to_plain {
    my ($markdown, $columns) = @_;

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

    local $Text::Wrap::columns = $columns
      if defined $columns;

    # do not wrap long words such as urls; see #719769
    local $Text::Wrap::huge = 'overflow';

    my @paragraphs = split(/\n{2,}/, $plain);

    my @lines;
    for my $paragraph (@paragraphs) {

        # do not wrap preformatted paragraphs
        unless ($paragraph =~ /^\s/) {

            # reduce whitespace throughout, including newlines
            $paragraph =~ s/\s+/ /g;

            # trim beginning and end of each line
            $paragraph =~ s/^\s+|\s+$//mg;

            $paragraph = wrap($EMPTY, $EMPTY, $paragraph);
        }

        push(@lines, $EMPTY);
        push(@lines, split(/\n/, $paragraph));
    }

    # drop leading blank line
    shift @lines;

    my $wrapped;
    $wrapped .= $_ . $NEWLINE for @lines;

    return $wrapped;
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

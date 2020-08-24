# -*- perl -*-
# Lintian::Tag::Info -- interface to tag metadata

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2009 Russ Allbery
# Copyright © 2020 Felix Lechner
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

package Lintian::Tag::Info;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use HTML::Entities;
use List::MoreUtils qw(none);
use Text::Wrap;

use Lintian::Data;
use Lintian::Deb822::File;

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant SLASH => q{/};
use constant COMMA => q{,};
use constant NEWLINE => qq{\n};

use constant HTML_PARAGRAPH_START => q{<p>};
use constant HTML_PARAGRAPH_END => q{</p>};

use Moo;
use namespace::clean;

# Ordered lists of severities, used for display level parsing.
our @SEVERITIES= qw(classification pedantic info warning error);

# loads the first time info is called
our $MANUALS
  = Lintian::Data->new('output/manual-references', qr/::/,\&_load_manual_data);

sub _load_manual_data {
    my ($key, $rawvalue, $pval) = @_;

    my ($section, $title, $url) = split m/::/, $rawvalue, 3;
    my $ret;
    if (not defined $pval) {
        $ret = $pval = {};
    }

    $pval->{$section}{title} = $title;
    $pval->{$section}{url} = $url;

    return $ret;
}

=head1 NAME

Lintian::Tag::Info - Lintian interface to tag metadata

=head1 SYNOPSIS

    my $taginfo = Lintian::Tag::Info->new;

=head1 DESCRIPTION

This module provides an interface to tag metadata as gleaned from the
*.desc files describing the checks.  It can be used to retrieve specific
metadata elements or to format the tag description.

=head1 INSTANCE METHODS

=over 4

=item tag

=item original_severity

=item effective_severity

=item check

=item name_spaced

=item check_type

=item experimental

=item explanation

=item references

=item aliases

=cut

has name => (
    is => 'rw',
    coerce => sub { my ($text) = @_; return ($text // EMPTY); },
    default => EMPTY
);

has original_severity => (
    is => 'rw',
    lazy => 1,
    coerce => sub {
        my ($text) = @_;

        $text //= EMPTY;
        croak "Unknown tag severity $text"
          if none { $text eq $_ } @SEVERITIES;

        return $text;
    },
    default => EMPTY
);

has effective_severity => (
    is => 'rw',
    lazy => 1,
    coerce => sub {
        my ($text) = @_;

        $text //= EMPTY;
        croak "Unknown tag severity $text"
          if none { $text eq $_ } @SEVERITIES;

        return $text;
    },
    default => EMPTY
);

has check => (
    is => 'rw',
    coerce => sub { my ($text) = @_; return ($text // EMPTY); },
    default => EMPTY
);

has name_spaced => (
    is => 'rw',
    coerce => sub { my ($boolean) = @_; return ($boolean // 0); },
    default => 0
);

has check_type => (
    is => 'rw',
    coerce => sub { my ($text) = @_; return ($text // EMPTY); },
    default => EMPTY
);

has experimental => (
    is => 'rw',
    coerce => sub { my ($boolean) = @_; return ($boolean // 0); },
    default => 0
);

has explanation => (
    is => 'rw',
    coerce => sub { my ($arrayref) = @_; return ($arrayref // []); },
    default => sub { [] });

has references => (
    is => 'rw',
    coerce => sub { my ($text) = @_; return ($text // EMPTY); },
    default => EMPTY
);

has aliases => (
    is => 'rw',
    coerce => sub { my ($arrayref) = @_; return ($arrayref // []); },
    default => sub { [] });

=item load(PATH)

Loads a tag description from PATH.

=cut

sub load {
    my ($self, $tagpath) = @_;

    croak "Cannot read tag file from $tagpath"
      unless -r $tagpath;

    my $deb822 = Lintian::Deb822::File->new;
    my @sections = $deb822->read_file($tagpath);
    croak "$tagpath does not have exactly one paragraph"
      unless scalar @sections == 1;

    my $fields = $sections[0];

    $self->check($fields->value('Check'));
    $self->name_spaced($fields->value('Name-Spaced') eq 'yes');

    my $name = $fields->value('Tag');
    $name = $self->check . SLASH . $name
      if $self->name_spaced;

    $self->name($name);

    $self->original_severity($fields->value('Severity'));
    $self->experimental($fields->value('Experimental') eq 'yes');

    my $explanation = $fields->value('Explanation') || $fields->value('Info');

    # remove leading space in each line
    $explanation =~ s/^[ \t]//mg;

    # remove dot place holder for empty lines
    $explanation =~ s/^\.$//mg;

    # split into paragraphs
    my @paragraphs = split(/\n\n/, $explanation);

    # trim beginning and end
    s/^\s+|\s+$//g for @paragraphs;

    # replace contiguous white spaces with single spaces
    s/\s+/ /g for @paragraphs;

    $self->explanation(\@paragraphs);

    $self->references($fields->value('See-Also') || $fields->value('Ref'));

    $self->aliases([$fields->trimmed_list('Renamed-From')]);

    croak "No Tag field in $tagpath"
      unless length $self->name;

    $self->effective_severity($self->original_severity);

    return;
}

=item code()

Returns the one-letter code for the tag.  This will be a letter chosen
from C<E>, C<W>, C<I>, or C<P>, based on the tag severity, and
other attributes (such as whether experimental is set).  This code will
never be C<O> or C<X>; overrides and experimental tags are handled
separately.

=cut

# Map severity levels to tag codes.
our %CODES = (
    'error' => 'E',
    'warning' => 'W',
    'info' => 'I',
    'pedantic' => 'P',
    'classification' => 'C',
);

sub code {
    my ($self) = @_;

    return $CODES{$self->effective_severity};
}

=item description([FORMAT [, INDENT]])

Returns the formatted explanation for a tag.  FORMAT must
be either C<text> or C<html> and defaults to C<text> if no format is
specified.  If C<text>, returns wrapped paragraphs formatted in plain text
with a right margin matching the Text::Wrap default, preserving as
verbatim paragraphs that begin with whitespace.  If C<html>, return
paragraphs formatted in HTML.

If INDENT is specified, the string INDENT is prepended to each line of the
formatted output.

=cut

sub description {
    my ($self, $format, $indent) = @_;

    $format //= 'text';
    $indent //= EMPTY;

    croak "unknown output format $format"
      unless $format eq 'text' || $format eq 'html';

    my @paragraphs = @{$self->explanation};

    my @citations = split(/,/, $self->references);

    # trim both ends
    s/^\s+|\s+$//g for @citations;

    my @html_citations= map { html_citation($_) } @citations;

    push(@paragraphs, reference_statement(@html_citations))
      if @html_citations;

    push(@paragraphs, 'Severity: '. $self->original_severity);

    push(@paragraphs, 'Check: ' . $self->check)
      if length $self->check;

    push(@paragraphs, 'Renamed from: ' . join(SPACE, @{$self->aliases}))
      if @{$self->aliases};

    push(@paragraphs, 'This tag is experimental.')
      if $self->experimental;

    push(@paragraphs,
        'This tag is a classification. There is no issue in your package.')
      if $self->original_severity eq 'classification';

    # do not wrap long words like urls, see #719769
    local $Text::Wrap::huge = 'overflow';

    my $output;
    if ($format eq 'html') {

        # encapsulate in HTML paragraphs
        my @html
          = map { HTML_PARAGRAPH_START . $_ . HTML_PARAGRAPH_END } @paragraphs;

        # make page source legible
        my @wrapped = map { wrap(EMPTY, EMPTY, $_) } @html;

        # add empty lines between html paragraphs
        $output = join(NEWLINE . NEWLINE, @wrapped);

    } else {
        my @text = map { $self->dtml_to_text($_) } @paragraphs;

        my @wrapped;
        for my $paragraph (@text) {

            # do not wrap indented lines
            if ($paragraph =~ /^\s/) {
                push(@wrapped, $indent . $paragraph);

            } else {
                push(@wrapped, wrap($indent, $indent, $paragraph));
            }
        }

        $output = join(NEWLINE . $indent . NEWLINE, @wrapped) . NEWLINE;
    }

    return $output;
}

=item reference_statement

=cut

sub reference_statement {
    my @references = @_;

    return 'Additional references are not available.'
      unless @references;

    # remove and save last element
    my $last = pop @references;

    my $text        = EMPTY;
    my $oxfordcomma = (@references > 1 ? COMMA : EMPTY);
    $text = join(', ', @references) . "$oxfordcomma and "
      if @references;

    $text .= $last;

    return "Refer to $text for details.";
}

=item html_citation

=cut

sub html_citation {
    my ($citation) = @_;

    my $html;

    if ($citation =~ /^([\w-]+)\s+(.+)$/) {
        $html = html_from_manuals($1, $2);

    } elsif ($citation =~ /^([\w.-]+)\((\d\w*)\)$/) {
        my ($name, $section) = ($1, $2);
        my $url
          ="https://manpages.debian.org/cgi-bin/man.cgi?query=$name&amp;sektion=$section";
        $html = qq{the <a href="$url">$citation</a> manual page};

    } elsif ($citation =~ m,^(ftp|https?)://,) {
        $html = qq{<a href="$citation">$citation</a>};

    } elsif ($citation =~ m,^/,) {
        $html = qq{<a href="file://$citation">$citation</a>};

    } elsif ($citation =~ m,^#(\d+)$,) {
        my $url = "https://bugs.debian.org/$1";
        $html = qq{<a href="$url">$url</a>};
    }

    return $html // $citation;
}

=item html_from_manuals

=cut

sub html_from_manuals {
    my ($volume, $section) = @_;

    return EMPTY
      unless $MANUALS->known($volume);

    my $entry = $MANUALS->value($volume);

    # start with the citation to the overall manual.
    my $title = $entry->{''}{title};
    my $url   = $entry->{''}{url};
    my $html  = $url ? qq{<a href="$url">$title</a>} : $title;

    return $html
      unless length $section;

    # Add the section information, if present, and a direct link to that
    # section of the manual where possible.
    if ($section =~ /^[A-Z]+$/) {
        $html .= " appendix $section";

    } elsif ($section =~ /^\d+$/) {
        $html .= " chapter $section";

    } elsif ($section =~ /^[A-Z\d.]+$/) {
        $html .= " section $section";
    }

    if (exists $entry->{$section}) {
        my $section_title = $entry->{$section}{title};
        my $section_url   = $entry->{$section}{url};
        $html .=
          $section_url
          ? qq{ (<a href="$section_url">$section_title</a>)}
          : qq{ ($section_title)};
    }

    return $html;
}

=item dtml_to_text

=cut

sub dtml_to_text {
    my ($self, $line) = @_;

    # use angular brackets for emphasis
    $line =~ s{<i>|<em>}{&lt;}g;
    $line =~ s{</i>|</em>}{&gt;}g;

    # drop all other HTML tags
    $line =~ s{<[^>]+>}{}g;

    # substitute HTML entities
    $line = decode_entities($line);

    unless ($line =~ /^\s/) {

        # preformatted
        $line =~ s{\s\s+}{ }g;
        $line =~ s{^ }{};
        $line =~ s{ $}{};
    }

    return $line;
}

=back

=head1 AUTHOR

Originally written by Russ Allbery <rra@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

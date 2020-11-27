# -*- perl -*-
# Lintian::Tag -- interface to tag metadata

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

package Lintian::Tag;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use List::MoreUtils qw(none);

use Lintian::Data;
use Lintian::Deb822::File;

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant SLASH => q{/};
use constant COMMA => q{,};
use constant LEFT_PARENTHESIS => q{(};
use constant RIGHT_PARENTHESIS => q{)};

use constant PARAGRAPH_BREAK => qq{\n\n};

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

Lintian::Tag - Lintian interface to tag metadata

=head1 SYNOPSIS

    my $tag = Lintian::Tag->new;

=head1 DESCRIPTION

This module provides an interface to tag metadata as gleaned from the
*.desc files describing the checks.  It can be used to retrieve specific
metadata elements or to format the tag description.

=head1 INSTANCE METHODS

=over 4

=item tag

=item visibility

=item effective_severity

=item check

=item name_spaced

=item show_always

=item check_type

=item experimental

=item explanation

=item see_also

=item renamed_from

=cut

has name => (
    is => 'rw',
    coerce => sub { my ($text) = @_; return ($text // EMPTY); },
    default => EMPTY
);

has visibility => (
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

has show_always => (
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
    coerce => sub { my ($text) = @_; return ($text // EMPTY); },
    default => EMPTY
);

has see_also => (
    is => 'rw',
    coerce => sub { my ($arrayref) = @_; return ($arrayref // []); },
    default => sub { [] });

has renamed_from => (
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
    $self->show_always($fields->value('Show-Always') eq 'yes');

    my $name = $fields->value('Tag');
    $name = $self->check . SLASH . $name
      if $self->name_spaced;

    $self->name($name);

    $self->visibility($fields->value('Severity'));
    $self->experimental($fields->value('Experimental') eq 'yes');

    $self->explanation($fields->text('Explanation') || $fields->text('Info'));

    my @see_also
      = split(/,/, $fields->value('See-Also') || $fields->value('Ref'));

    # trim both ends of each
    s/^\s+|\s+$//g for @see_also;

    my @markdown = map { markdown_citation($_) } @see_also;
    $self->see_also(\@markdown);

    $self->renamed_from([$fields->trimmed_list('Renamed-From')]);

    croak "No Tag field in $tagpath"
      unless length $self->name;

    $self->effective_severity($self->visibility);

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

=item markdown_description

=cut

sub markdown_description {
    my ($self) = @_;

    my $description = $self->explanation;

    my @extras;

    my $references = $self->markdown_reference_statement;
    push(@extras, $references)
      if length $references;

    push(@extras, 'Severity: '. $self->visibility);

    push(@extras, 'Check: ' . $self->check)
      if length $self->check;

    push(@extras, 'Renamed from: ' . join(SPACE, @{$self->renamed_from}))
      if @{$self->renamed_from};

    push(@extras, 'This tag is experimental.')
      if $self->experimental;

    push(@extras,
        'This tag is a classification. There is no issue in your package.')
      if $self->visibility eq 'classification';

    $description .= PARAGRAPH_BREAK . $_ for @extras;

    return $description;
}

=item markdown_reference_statement

=cut

sub markdown_reference_statement {
    my ($self) = @_;

    my @references = @{$self->see_also};

    return EMPTY
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

=item markdown_citation

=cut

sub markdown_citation {
    my ($citation) = @_;

    my $markdown;

    if ($citation =~ /^([\w-]+)\s+(.+)$/) {
        $markdown = markdown_from_manuals($1, $2);

    } elsif ($citation =~ /^([\w.-]+)\((\d\w*)\)$/) {
        my ($name, $section) = ($1, $2);
        my $url
          ="https://manpages.debian.org/cgi-bin/man.cgi?query=$name&amp;sektion=$section";
        my $hyperlink = markdown_hyperlink($citation, $url);
        $markdown = "the $hyperlink manual page";

    } elsif ($citation =~ m{^(ftp|https?)://}) {
        $markdown = markdown_hyperlink(undef, $citation);

    } elsif ($citation =~ m{^/}) {
        $markdown = markdown_hyperlink($citation, "file://$citation");

    } elsif ($citation =~ m{^(?:Bug)?#(\d+)$}) {
        my $bugnumber = $1;
        $markdown
          = markdown_hyperlink($citation,"https://bugs.debian.org/$bugnumber");
    }

    return $markdown // $citation;
}

=item markdown_from_manuals

=cut

sub markdown_from_manuals {
    my ($volume, $section) = @_;

    return EMPTY
      unless $MANUALS->known($volume);

    my $entry = $MANUALS->value($volume);

    # start with the citation to the overall manual.
    my $title = $entry->{''}{title};
    my $url   = $entry->{''}{url};

    my $markdown = markdown_hyperlink($title, $url);

    return $markdown
      unless length $section;

    # Add the section information, if present, and a direct link to that
    # section of the manual where possible.
    if ($section =~ /^[A-Z]+$/) {
        $markdown .= " appendix $section";

    } elsif ($section =~ /^\d+$/) {
        $markdown .= " chapter $section";

    } elsif ($section =~ /^[A-Z\d.]+$/) {
        $markdown .= " section $section";
    }

    return $markdown
      unless exists $entry->{$section};

    my $section_title = $entry->{$section}{title};
    my $section_url   = $entry->{$section}{url};

    $markdown
      .= SPACE
      . LEFT_PARENTHESIS
      . markdown_hyperlink($section_title, $section_url)
      . RIGHT_PARENTHESIS;

    return $markdown;
}

=item markdown_hyperlink

=cut

sub markdown_hyperlink {
    my ($text, $url) = @_;

    return $text
      unless length $url;

    return "<$url>"
      unless length $text;

    return "[$text]($url)";
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

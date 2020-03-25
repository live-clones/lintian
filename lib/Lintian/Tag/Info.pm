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

use strict;
use warnings;

use Carp qw(croak);
use List::MoreUtils qw(none);

use Lintian::Data;
use Lintian::Deb822Parser qw(read_dpkg_control_utf8);
use Lintian::Tag::TextUtil
  qw(dtml_to_html dtml_to_text split_paragraphs wrap_paragraphs);

use constant EMPTY => q{};
use constant SPACE => q{ };

use Moo;
use namespace::clean;

# Ordered lists of severities, used for display level parsing.
our @SEVERITIES= qw(classification pedantic info warning error);

# The URL to a web man page service.  NAME is replaced by the man page
# name and SECTION with the section to form a valid URL.  This is used
# when formatting references to manual pages into HTML to provide a link
# to the manual page.
our $MANURL
  = 'https://manpages.debian.org/cgi-bin/man.cgi?query=NAME&amp;sektion=SECTION';

# Stores the parsed manual reference data.  Loaded the first time info()
# is called.
our $MANUALS
  = Lintian::Data->new('output/manual-references', qr/::/,\&_load_manual_data);

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

=item check_type

=item experimental

=item info

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

has info => (
    is => 'rw',
    coerce => sub { my ($text) = @_; return ($text // EMPTY); },
    default => EMPTY
);

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

    my @paragraphs = read_dpkg_control_utf8($tagpath);
    croak "$tagpath does not have exactly one paragraph"
      unless scalar @paragraphs == 1;

    my %fields = %{ $paragraphs[0] };
    $self->name($fields{tag});
    $self->original_severity($fields{severity});

    $self->check($fields{check});
    $self->experimental(($fields{experimental} // EMPTY) eq 'yes');

    $self->info($fields{info});
    $self->references($fields{ref});

    $self->aliases(split(SPACE, $fields{'renamed-from'} // EMPTY));

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

Returns the formatted description (the Info field) for a tag.  FORMAT must
be either C<text> or C<html> and defaults to C<text> if no format is
specified.  If C<text>, returns wrapped paragraphs formatted in plain text
with a right margin matching the Text::Wrap default, preserving as
verbatim paragraphs that begin with whitespace.  If C<html>, return
paragraphs formatted in HTML.

If INDENT is specified, the string INDENT is prepended to each line of the
formatted output.

=cut

# Parse manual reference data from the data file.
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

# Format a reference to a manual in the HTML that Lintian uses internally
# for tag descriptions and return the result.  Takes the name of the
# manual and the name of the section.  Returns an empty string if the
# argument isn't a known manual.
sub _manual_reference {
    my ($manual, $section) = @_;
    return '' unless $MANUALS->known($manual);

    my $man = $MANUALS->value($manual);
    # Start with the reference to the overall manual.
    my $title = $man->{''}{title};
    my $url   = $man->{''}{url};
    my $text  = $url ? qq(<a href="$url">$title</a>) : $title;

    # Add the section information, if present, and a direct link to that
    # section of the manual where possible.
    if ($section and $section =~ /^[A-Z]+$/) {
        $text .= " appendix $section";
    } elsif ($section and $section =~ /^\d+$/) {
        $text .= " chapter $section";
    } elsif ($section and $section =~ /^[A-Z\d.]+$/) {
        $text .= " section $section";
    }
    if ($section and exists $man->{$section}) {
        my $sec_title = $man->{$section}{title};
        my $sec_url   = $man->{$section}{url};
        $text.=
          $sec_url
          ? qq[ (<a href="$sec_url">$sec_title</a>)]
          : qq[ ($sec_title)];
    }

    return $text;
}

# Format the contents of the Ref attribute of a tag.  Handles manual
# references in the form <keyword> <section>, manpage references in the
# form <manpage>(<section>), and URLs.
sub _format_reference {
    my ($field) = @_;
    my @refs;
    for my $ref (split(/,\s*/, $field)) {
        my $text;
        if ($ref =~ /^([\w-]+)\s+(.+)$/) {
            $text = _manual_reference($1, $2);
        } elsif ($ref =~ /^([\w.-]+)\((\d\w*)\)$/) {
            my ($name, $section) = ($1, $2);
            my $url = $MANURL;
            $url =~ s/NAME/$name/g;
            $url =~ s/SECTION/$section/g;
            $text = qq(the <a href="$url">$ref</a> manual page);
        } elsif ($ref =~ m,^(ftp|https?)://,) {
            $text = qq(<a href="$ref">$ref</a>);
        } elsif ($ref =~ m,^/,) {
            $text = qq(<a href="file://$ref">$ref</a>);
        } elsif ($ref =~ m,^#(\d+)$,) {
            my $url = qq(https://bugs.debian.org/$1);
            $text = qq(<a href="$url">$url</a>);
        }
        push(@refs, $text) if $text;
    }

    # Now build an English list of the results with appropriate commas and
    # conjunctions.
    my $text = '';
    if ($#refs >= 2) {
        $text = join(', ', splice(@refs, 0, $#refs));
        $text = "Refer to $text, and @refs for details.";
    } elsif ($#refs >= 0) {
        $text = 'Refer to ' . join(' and ', @refs) . ' for details.';
    }
    return $text;
}

# Returns the formatted tag description.
sub description {
    my ($self, $format, $indent) = @_;

    $format //= 'text';
    croak "unknown output format $format"
      unless $format eq 'text' || $format eq 'html';

    # build tag description
    my $info = $self->info;

    # remove leading spaces
    $info =~ s/\n[ \t]/\n/g;

    my @paragraphs = split_paragraphs($info);

    push(@paragraphs, EMPTY, _format_reference($self->references))
      if length $self->references;

    push(@paragraphs, EMPTY,'Severity: '. $self->original_severity);

    push(@paragraphs, EMPTY, 'Check: ' . $self->check)
      if length $self->check;

    push(@paragraphs,
        EMPTY,
'This tag is experimental. Please file a bug report if the tag seems wrong.'
    )if $self->experimental;

    push(@paragraphs,
        EMPTY,
        'This tag is a classification. There is no issue in your package.')
      if $self->original_severity eq 'classification';

    $indent //= EMPTY;

    return wrap_paragraphs('HTML', $indent, dtml_to_html(@paragraphs))
      if $format eq 'html';

    return wrap_paragraphs($indent, dtml_to_text(@paragraphs));
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

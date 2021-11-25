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
use Const::Fast;
use Email::Address::XS;
use List::SomeUtils qw(none first_value);
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Deb822::File;

use Moo;
use namespace::clean;

const my $EMPTY => q{};
const my $SLASH => q{/};

# Ordered lists of visibilities, used for display level parsing.
our @VISIBILITIES= qw(classification pedantic info warning error);

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

=item name

=item visibility

=item check

=item name_spaced

=item show_always

=item experimental

=item explanation

=item see_also

=item renamed_from

=item profile

=cut

has name => (
    is => 'rw',
    coerce => sub { my ($text) = @_; return ($text // $EMPTY); },
    default => $EMPTY
);

has visibility => (
    is => 'rw',
    lazy => 1,
    coerce => sub {
        my ($text) = @_;

        $text //= $EMPTY;
        croak encode_utf8("Unknown tag visibility $text")
          if none { $text eq $_ } @VISIBILITIES;

        return $text;
    },
    default => $EMPTY
);

has check => (
    is => 'rw',
    coerce => sub { my ($text) = @_; return ($text // $EMPTY); },
    default => $EMPTY
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

has experimental => (
    is => 'rw',
    coerce => sub { my ($boolean) = @_; return ($boolean // 0); },
    default => 0
);

has explanation => (
    is => 'rw',
    coerce => sub { my ($text) = @_; return ($text // $EMPTY); },
    default => $EMPTY
);

has see_also => (
    is => 'rw',
    coerce => sub { my ($arrayref) = @_; return ($arrayref // []); },
    default => sub { [] });

has renamed_from => (
    is => 'rw',
    coerce => sub { my ($arrayref) = @_; return ($arrayref // []); },
    default => sub { [] });

has screens => (
    is => 'rw',
    coerce => sub { my ($arrayref) = @_; return ($arrayref // []); },
    default => sub { [] });

=item load(PATH)

Loads a tag description from PATH.

=cut

sub load {
    my ($self, $profile, $tagpath) = @_;

    croak encode_utf8('No profile')
      unless defined $profile;

    croak encode_utf8("Cannot read tag file from $tagpath")
      unless -r $tagpath;

    my $deb822 = Lintian::Deb822::File->new;
    my @sections = $deb822->read_file($tagpath);

    my $fields = shift @sections;

    $self->check($fields->value('Check'));
    $self->name_spaced($fields->value('Name-Spaced') eq 'yes');
    $self->show_always($fields->value('Show-Always') eq 'yes');

    my $name = $fields->value('Tag');
    $name = $self->check . $SLASH . $name
      if $self->name_spaced;

    $self->name($name);

    $self->visibility($fields->value('Severity'));
    $self->experimental($fields->value('Experimental') eq 'yes');

    $self->explanation($fields->text('Explanation') || $fields->text('Info'));

    my @see_also = $fields->trimmed_list('See-Also', qr{,});
    @see_also = $fields->trimmed_list('Ref', qr{,})
      unless @see_also;

    my $manuals = $profile->manual_references;

    my @markdown = map { $manuals->markdown_citation($_) } @see_also;
    $self->see_also(\@markdown);

    $self->renamed_from([$fields->trimmed_list('Renamed-From')]);

    croak encode_utf8("No Tag field in $tagpath")
      unless length $self->name;

    my @screens;
    for my $section (@sections) {

        my $screen_name = $section->value('Screen');

        my $relative = $screen_name;
        $relative =~ s{^([[:lower:]])}{\U$1};
        $relative =~ s{/([[:lower:]])}{/\U$1}g;
        $relative =~ s{-([[:lower:]])}{\U$1}g;

        my @candidates = map {
            ("$_/lib/Lintian/Screen/$relative.pm", "$_/screens/relative.pm")
        } @{$profile->safe_include_dirs};

        my $absolute = first_value { -e } @candidates;
        require $absolute;

        my $module = $relative;
        $module =~ s{/}{::}g;

        my $screen = "Lintian::Screen::$module"->new;

        $screen->name($screen_name);

        my @advocates= Email::Address::XS->parse($section->value('Advocates'));
        $screen->advocates(\@advocates);

        $screen->reason($section->text('Reason'));

        my @see_also_screen = $section->trimmed_list('See-Also', qr{,});
        my @markdown_screen
          = map { $manuals->markdown_citation($_) } @see_also_screen;
        $screen->see_also(\@markdown_screen);

        push(@screens, $screen);
    }

    $self->screens(\@screens);

    return;
}

=item code()

Returns the one-letter code for the tag.  This will be a letter chosen
from C<E>, C<W>, C<I>, or C<P>, based on the tag visibility, and
other attributes (such as whether experimental is set).  This code will
never be C<O> or C<X>; overrides and experimental tags are handled
separately.

=cut

# Map visibility levels to tag codes.
our %CODES = (
    'error' => 'E',
    'warning' => 'W',
    'info' => 'I',
    'pedantic' => 'P',
    'classification' => 'C',
);

sub code {
    my ($self) = @_;

    return $CODES{$self->visibility};
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

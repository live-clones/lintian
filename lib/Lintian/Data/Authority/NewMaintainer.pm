# -*- perl -*-
#
# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2001 Colin Watson
# Copyright © 2008 Jordà Polo
# Copyright © 2009 Russ Allbery
# Copyright © 2017-2019 Chris Lamb <lamby@debian.org>
# Copyright © 2020-2021 Felix Lechner
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

package Lintian::Data::Authority::NewMaintainer;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Const::Fast;
use List::SomeUtils qw(any first_value);
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);
use WWW::Mechanize ();

use Lintian::Output::Markdown qw(markdown_authority);

const my $SLASH => q{/};
const my $UNDERSCORE => q{_};

const my $VOLUME_KEY => $UNDERSCORE;
const my $SECTIONS => 'sections';

use Moo;
use namespace::clean;

with 'Lintian::Data::PreambledJSON';

=head1 NAME

Lintian::Data::Authority::NewMaintainer - Lintian interface for manual references

=head1 SYNOPSIS

    use Lintian::Data::Authority::NewMaintainer;

=head1 DESCRIPTION

Lintian::Data::Authority::NewMaintainer provides a way to load data files for
manual references.

=head1 CLASS METHODS

=over 4

=item title

=item shorthand

=item location

=item by_section_key

=cut

has title => (
    is => 'rw',
    default => 'New Maintainer\'s Guide'
);

has shorthand => (
    is => 'rw',
    default => 'new-maintainer'
);

has location => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return 'authority/' . $self->shorthand . '.json';
    });

has by_section_key => (is => 'rw', default => sub { {} });

=item markdown_citation

=cut

sub markdown_citation {
    my ($self, $section_key) = @_;

    croak "Invalid section $section_key"
      if $section_key eq $VOLUME_KEY;

    my $volume_entry = $self->value($VOLUME_KEY);

    # start with the citation to the overall manual.
    my $volume_title = $volume_entry->{title};
    my $volume_url   = $volume_entry->{destination};

    my $section_title;
    my $section_url;

    if ($self->recognizes($section_key)) {

        my $section_entry = $self->value($section_key);

        $section_title = $section_entry->{title};
        $section_url   = $section_entry->{destination};
    }

    return markdown_authority(
        $volume_title, $volume_url,$section_key,
        $section_title, $section_url
    );
}

=item recognizes (KEY)

Returns true if KEY is known, and false otherwise.

=cut

sub recognizes {
    my ($self, $key) = @_;

    return 0
      unless length $key;

    return 1
      if exists $self->by_section_key->{$key};

    return 0;
}

=item value (KEY)

Returns the value attached to KEY if it was listed in the data
file represented by this Lintian::Data instance and the undefined value
otherwise.

=cut

sub value {
    my ($self, $key) = @_;

    return undef
      unless length $key;

    return $self->by_section_key->{$key};
}

=item load

=cut

sub load {
    my ($self, $search_space, $our_vendor) = @_;

    my @candidates = map { $_ . $SLASH . $self->location } @{$search_space};
    my $path = first_value { -e } @candidates;

    my $reference;
    $self->read_file($path, \$reference);
    my @sections = @{$reference // []};

    for my $section (@sections) {

        my $key = $section->{key};

        # only store first value for duplicates
        # silently ignore later values
        $self->by_section_key->{$key} //= $section;
    }

    return;
}

=item refresh

=cut

sub refresh {
    my ($self, $archive, $basedir) = @_;

    my $base_url = 'https://www.debian.org/doc/manuals/maint-guide/index.html';

    my $mechanize = WWW::Mechanize->new();
    $mechanize->get($base_url);

    my $page_title = $mechanize->title;

    my @sections;

    # underscore is a token for the whole page
    my %volume;
    $volume{key} = $VOLUME_KEY;
    $volume{title} = $page_title;
    $volume{destination} = $base_url;

    # store array to resemble web layout
    # may contain duplicates
    push(@sections, \%volume);

    my $in_appendix = 0;

    # https://stackoverflow.com/a/254687
    for my $link ($mechanize->links) {

        next
          unless length $link->text;

        next
          if $link->text !~ qr{^ \s* ([.\d[:upper:]]+) \s+ (.+) $}x;

        my $section_key = $1;
        my $section_title = $2;

        # drop final dots
        $section_key =~ s{ [.]+ $}{}x;

        # reduce consecutive whitespace
        $section_title =~ s{ \s+ }{ }gx;

        my $destination = $base_url . $link->url;

        my @similar = grep { $_->{key} eq $section_key } @sections;
        next
          if (any { $_->{title} eq $section_title } @similar)
          || (any { $_->{destination} eq $destination } @similar);

        # Some manuals reuse section numbers for different references,
        # e.g. the Debian Policy's normal and appendix sections are
        # numbers that clash with each other. Track if we've already
        # seen a section pointing to some other URL than the current one,
        # and prepend it with an indicator
        $in_appendix = 1
          if any { $_->{destination} ne $destination } @similar;

        $section_key = "appendix-$section_key"
          if $in_appendix;

        my %section;
        $section{key} = $section_key;
        $section{title} = $section_title;
        $section{destination} = $destination;
        push(@sections, \%section);
    }

    my $data_path = "$basedir/" . $self->location;
    $self->write_file($SECTIONS, \@sections, $data_path);

    return;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

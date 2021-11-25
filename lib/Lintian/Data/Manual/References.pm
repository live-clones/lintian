# -*- perl -*-
#
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

package Lintian::Data::Manual::References;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Moo;
use namespace::clean;

with 'Lintian::Data';

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $LEFT_PARENTHESIS => q{(};
const my $RIGHT_PARENTHESIS => q{)};

const my $THREE_PARTS => 3;

=head1 NAME

Lintian::Data::Manual::References - Lintian interface for manual references

=head1 SYNOPSIS

    use Lintian::Data::Manual::References;

=head1 DESCRIPTION

Lintian::Data::Manual::References provides a way to load data files for
manual references.

=head1 CLASS METHODS

=over 4

=item title

=item location

=item separator

=item accumulator

=cut

has title => (
    is => 'rw',
    default => 'Manual References'
);

has location => (
    is => 'rw',
    default => 'output/manual-references'
);

has separator => (
    is => 'rw',
    default => sub { qr/::/ });

has accumulator => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return sub {
            my ($key, $remainder, $previous) = @_;

            return undef
              if defined $previous;

            my ($section, $title, $url)
              = split($self->separator, $remainder, $THREE_PARTS);

            my %entry;
            $entry{$section}{title} = $title;
            $entry{$section}{url} = $url;

            return \%entry;
        };
    });

=item markdown_citation

=cut

sub markdown_citation {
    my ($self, $citation) = @_;

    my $markdown;

    if ($citation =~ /^([\w-]+)\s+(.+)$/) {
        $markdown = $self->markdown_from_manuals($1, $2);

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
    my ($self, $volume, $section) = @_;

    return $EMPTY
      unless $self->recognizes($volume);

    my $entry = $self->value($volume);

    # start with the citation to the overall manual.
    my $title = $entry->{$EMPTY}{title};
    my $url   = $entry->{$EMPTY}{url};

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
      .= $SPACE
      . $LEFT_PARENTHESIS
      . markdown_hyperlink($section_title, $section_url)
      . $RIGHT_PARENTHESIS;

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

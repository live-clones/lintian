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

package Lintian::Data::Authority::FilesystemHierarchy;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Const::Fast;
use File::Basename qw(dirname);
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);
use WWW::Mechanize ();

use Lintian::Output::Markdown qw(markdown_authority);

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $SLASH => q{/};
const my $COLON => q{:};
const my $UNDERSCORE => q{_};
const my $LEFT_PARENTHESIS => q{(};
const my $RIGHT_PARENTHESIS => q{)};

const my $TWO_PARTS => 2;

const my $VOLUME_KEY => $UNDERSCORE;
const my $SEPARATOR => $COLON x 2;

use Moo;
use namespace::clean;

with 'Lintian::Data';

=head1 NAME

Lintian::Data::Authority::FilesystemHierarchy - Lintian interface for manual references

=head1 SYNOPSIS

    use Lintian::Data::Authority::FilesystemHierarchy;

=head1 DESCRIPTION

Lintian::Data::Authority::FilesystemHierarchy provides a way to load data files for
manual references.

=head1 CLASS METHODS

=over 4

=item title

=item shorthand

=item location

=item separator

=item accumulator

=cut

has title => (
    is => 'rw',
    default => 'Filesystem Hierarchy Standard'
);

has shorthand => (
    is => 'rw',
    default => 'filesystem-hierarchy'
);

has location => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return 'authority/' . $self->shorthand;
    });

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

            my ($title, $url)= split($self->separator, $remainder, $TWO_PARTS);

            my %entry;
            $entry{title} = $title;
            $entry{url} = $url;

            return \%entry;
        };
    });

=item markdown_citation

=cut

sub markdown_citation {
    my ($self, $section_key) = @_;

    croak "Invalid section $section_key"
      if $section_key eq $VOLUME_KEY;

    my $volume_entry = $self->value($VOLUME_KEY);

    # start with the citation to the overall manual.
    my $volume_title = $volume_entry->{title};
    my $volume_url   = $volume_entry->{url};

    my $section_title;
    my $section_url;

    if ($self->recognizes($section_key)) {

        my $section_entry = $self->value($section_key);

        $section_title = $section_entry->{title};
        $section_url   = $section_entry->{url};
    }

    return markdown_authority(
        $volume_title, $volume_url,$section_key,
        $section_title, $section_url
    );
}

=item write_line

=cut

sub write_line {
    my ($data_fd, $section_key, $section_title, $destination) = @_;

    # drop final dots
    $section_key =~ s{ [.]+ $}{}x;

    # reduce consecutive whitespace
    $section_title =~ s{ \s+ }{ }gx;

    my $line= join($SEPARATOR,$section_key, $section_title, $destination);

    say {$data_fd} encode_utf8($line);

    return;
}

=item write_data_file

=cut

sub write_data_file {
    my ($self, $basedir, $generated) = @_;

    my $header =<<"HEADER";
# Data about titles, sections, and URLs of manuals, used to expand references
# in tag descriptions and add links for HTML output.  Each line of this file
# has three fields separated by double colons:
#
#     <section> :: <title> :: <url>
#
# If <section> is an underscore, that line specifies the title and URL for the
# whole manual.

HEADER

    my $data_path = "$basedir/" . $self->location;
    my $parent_dir = path($data_path)->parent->stringify;
    path($parent_dir)->mkpath
      unless -e $parent_dir;

    my $output = encode_utf8($header) . $generated;
    path($data_path)->spew($output);

    return;
}

=item extract_sections_from_links

=cut

sub extract_sections_from_links {
    my ($self, $data_fd, $base_url, $page_name)= @_;

    my $page_url = $base_url . $page_name;

    my $mechanize = WWW::Mechanize->new();
    $mechanize->get($page_url);

    my $page_title = $mechanize->title;

    # strip explanatory remark
    $page_title =~ s{ \s* \N{EM DASH} .* $}{}x;

    # underscore is a token for the whole page
    write_line($data_fd, $VOLUME_KEY, $page_title, $page_url);

    my %by_section_key;
    my $in_appendix = 0;

    # https://stackoverflow.com/a/254687
    for my $link ($mechanize->links) {

        next
          unless length $link->text;

        next
          if $link->text !~ qr{^ \s* ([.\d]+) \s+ (.+) $}x;

        my $section_key = $1;
        my $section_title = $2;

        # drop final dots
        $section_key =~ s{ [.]+ $}{}x;

        # reduce consecutive whitespace
        $section_title =~ s{ \s+ }{ }gx;

        my $relative_destination = $link->url;

        my $destination_base = $page_url;
        $destination_base = dirname($page_url) . $SLASH
          unless $destination_base =~ m{ / $}x
          || $relative_destination =~ m{^ [#] }x;

        my $full_destination = $destination_base . $relative_destination;

        next
          if exists $by_section_key{$section_key}
          && ( $by_section_key{$section_key}{title} eq $section_title
            || $by_section_key{$section_key}{destination} eq$full_destination);

        # Some manuals reuse section numbers for different references,
        # e.g. the Debian Policy's normal and appendix sections are
        # numbers that clash with each other. Track if we've already
        # seen a section pointing to some other URL than the current one,
        # and prepend it with an indicator
        $in_appendix = 1
          if exists $by_section_key{$section_key}
          && $by_section_key{$section_key}{destination} ne$full_destination;

        $section_key = "appendix-$section_key"
          if $in_appendix;

        $by_section_key{$section_key}{title} = $section_title;
        $by_section_key{$section_key}{destination} = $full_destination;

        write_line($data_fd, $section_key, $section_title, $full_destination);
    }

    return;
}

=item refresh

=cut

sub refresh {
    my ($self, $archive, $basedir) = @_;

    # single page version
    # plain directory shows a file list
    my $base_url = 'https://refspecs.linuxfoundation.org/FHS_3.0/';
    my $index_name = 'fhs-3.0.html';

    my $generated;
    open(my $memory_fd, '>', \$generated)
      or die encode_utf8('Cannot open scalar');

    $self->extract_sections_from_links($memory_fd, $base_url, $index_name);

    close $memory_fd;

    $self->write_data_file($basedir, $generated);

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

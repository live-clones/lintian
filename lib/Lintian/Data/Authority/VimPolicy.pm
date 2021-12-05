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

package Lintian::Data::Authority::VimPolicy;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Const::Fast;
use HTML::TokeParser::Simple;
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Output::Markdown qw(markdown_authority);

const my $EMPTY => q{};
const my $SPACE => q{ };
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

Lintian::Data::Authority::VimPolicy - Lintian interface for manual references

=head1 SYNOPSIS

    use Lintian::Data::Authority::VimPolicy;

=head1 DESCRIPTION

Lintian::Data::Authority::VimPolicy provides a way to load data files for
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
    default => 'Vim Policy'
);

has shorthand => (
    is => 'rw',
    default => 'vim-policy'
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

=item C<extract_vim>

=cut

sub extract_vim {
    my ($self, $data_fd, $base_url, $page_name)= @_;

    my $page_url = $base_url . $page_name;

    my $parser = HTML::TokeParser::Simple->new(url => $page_url);
    my $in_title = 0;
    my $in_dt_tag = 0;
    my $after_a_tag = 0;

    my $page_title = $EMPTY;
    my $section_key = $EMPTY;
    my $section_title = $EMPTY;
    my $relative_destination = $EMPTY;

    while (my $token = $parser->get_token) {

        if (length $token->get_tag) {

            if ($token->get_tag eq 'h1') {

                $in_title = ($token->is_start_tag
                      && $token->get_attr('class') eq 'title');

                # not yet leaving title
                next
                  if $in_title;

                # trim both ends
                $page_title =~ s/^\s+|\s+$//g;

                # underscore is a token for the whole page
                write_line($data_fd, $VOLUME_KEY, $page_title, $page_url)
                  if length $page_title;

                $page_title = $EMPTY;
            }

            if ($token->get_tag eq 'dt') {

                $in_dt_tag = $token->is_start_tag;

                # not yet leaving dt tag
                next
                  if $in_dt_tag;

                # trim both ends
                $section_key =~ s/^\s+|\s+$//g;
                $section_title =~ s/^\s+|\s+$//g;

                my $full_destination = $base_url . $relative_destination;

                write_line($data_fd, $section_key, $section_title,
                    $full_destination)
                  if length $section_title;

                $section_key = $EMPTY;
                $section_title = $EMPTY;
                $relative_destination = $EMPTY;
            }

            if ($token->get_tag eq 'a') {

                $after_a_tag = $token->is_start_tag;

                $relative_destination = $token->get_attr('href')
                  if $token->is_start_tag;
            }

        } else {

            # concatenate span objects
            $page_title .= $token->as_is
              if length $token->as_is
              && $in_title
              && $after_a_tag;

            $section_key = $token->as_is
              if length $token->as_is
              && $in_dt_tag
              && !$after_a_tag;

            # concatenate span objects
            $section_title .= $token->as_is
              if length $token->as_is
              && $in_dt_tag
              && $after_a_tag;
        }
    }

    return;
}

=item refresh

=cut

sub refresh {
    my ($self, $archive, $basedir) = @_;

    # shipped as part of the vim installable
    my $base_url = 'file:///usr/share/doc/vim/vim-policy.html/';
    my $index_name = 'index.html';

    my $generated;
    open(my $memory_fd, '>', \$generated)
      or die encode_utf8('Cannot open scalar');

    $self->extract_vim($memory_fd, $base_url, $index_name);

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

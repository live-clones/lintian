# -*- perl -*-
#
# Copyright (C) 1998 Christian Schwarz and Richard Braakman
# Copyright (C) 2001 Colin Watson
# Copyright (C) 2008 Jorda Polo
# Copyright (C) 2009 Russ Allbery
# Copyright (C) 2017-2019 Chris Lamb <lamby@debian.org>
# Copyright (C) 2020-2021 Felix Lechner
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
use File::Basename qw(basename);
use IPC::Run3;
use HTML::TokeParser::Simple;
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Output::Markdown qw(markdown_authority);

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $SLASH => q{/};
const my $COLON => q{:};
const my $INDENT => $SPACE x 4;
const my $UNDERSCORE => q{_};
const my $LEFT_PARENTHESIS => q{(};
const my $RIGHT_PARENTHESIS => q{)};

const my $TWO_PARTS => 2;

const my $VOLUME_KEY => $UNDERSCORE;
const my $SEPARATOR => $COLON x 2;

const my $WAIT_STATUS_SHIFT => 8;

use Moo;
use namespace::clean;

with 'Lintian::Data::JoinedLines';

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
    }
);

has separator => (
    is => 'rw',
    default => sub { qr/::/ }
);

=item consumer

=cut

sub consumer {
    my ($self, $key, $remainder, $previous) = @_;

    return undef
      if defined $previous;

    my ($title, $url)= split($self->separator, $remainder, $TWO_PARTS);

    my %entry;
    $entry{title} = $title;
    $entry{url} = $url;

    return \%entry;
}

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

=item find_installable_name

=cut

sub find_installable_name {
    my ($self, $archive, $release, $liberty, $port, $requested_path) = @_;

    my @installed_by;

    # find installable package
    for my $installable_architecture ('all', $port) {

        my $local_path
          = $archive->contents_gz($release, $liberty,
            $installable_architecture);

        open(my $fd, '<:gzip', $local_path)
          or die encode_utf8("Cannot open $local_path.");

        while (my $line = <$fd>) {

            chomp $line;

            my ($path, $finder) = split($SPACE, $line, 2);
            next
              unless length $path
              && length $finder;

            if ($path eq $requested_path) {

                my $name = $1;

                my @locations = split(m{,}, $finder);
                for my $location (@locations) {

                    my ($section, $installable)= split(m{/}, $location, 2);

                    push(@installed_by, $installable);
                }

                next;
            }
        }

        close $fd;
    }

    die encode_utf8(
        "The path $requested_path is not installed by any package.")
      if @installed_by < 1;

    if (@installed_by > 1) {
        warn encode_utf8(
            "The path $requested_path is installed by multiple packages:\n");
        warn encode_utf8($INDENT . "- $_\n")for @installed_by;
    }

    my $installable_name = shift @installed_by;

    return $installable_name;
}

=item refresh

=cut

sub refresh {
    my ($self, $archive, $basedir) = @_;

    # shipped as part of the vim installable
    my $shipped_base = 'usr/share/doc/vim/vim-policy.html/';
    my $index_name = 'index.html';

    my $shipped_path = $shipped_base . $index_name;
    my $stored_uri = "file:///$shipped_base";

    # neutral sort order
    local $ENV{LC_ALL} = 'C';

    my $release = 'stable';
    my $port = 'amd64';

    my $installable_name
      = $self->find_installable_name($archive, $release, 'main', $port,
        $shipped_path);

    my $deb822_by_installable_name
      = $archive->deb822_packages_by_installable_name($release, 'main', $port);

    my $work_folder
      = Path::Tiny->tempdir(
        TEMPLATE => 'refresh-doc-base-specification-XXXXXXXXXX');

    die encode_utf8("Installable $installable_name not shipped in port $port")
      unless exists $deb822_by_installable_name->{$installable_name};

    my $deb822 = $deb822_by_installable_name->{$installable_name};

    my $pool_path = $deb822->value('Filename');

    my $deb_filename = basename($pool_path);
    my $deb_local_path = "$work_folder/$deb_filename";
    my $deb_url = $archive->mirror_base . $SLASH . $pool_path;

    my $stderr;
    run3([qw{wget --quiet}, "--output-document=$deb_local_path", $deb_url],
        undef, \$stderr);
    my $status = ($? >> $WAIT_STATUS_SHIFT);

    # stderr already in UTF-8
    die $stderr
      if $status;

    my $extract_folder = "$work_folder/unpacked/$pool_path";
    path($extract_folder)->mkpath;

    run3([qw{dpkg-deb --extract}, $deb_local_path, $extract_folder],
        undef, \$stderr);
    $status = ($? >> $WAIT_STATUS_SHIFT);

    # stderr already in UTF-8
    die $stderr
      if $status;

    unlink($deb_local_path)
      or die encode_utf8("Cannot delete $deb_local_path");

    my $generated;
    open(my $memory_fd, '>', \$generated)
      or die encode_utf8("Cannot open scalar: $!");

    my $fresh_uri = URI::file->new_abs("/$extract_folder/$shipped_path");

    my $parser = HTML::TokeParser::Simple->new(url => $fresh_uri);
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
                write_line($memory_fd, $VOLUME_KEY, $page_title,
                    $stored_uri . $index_name)
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

                my $full_destination = $stored_uri . $relative_destination;

                write_line(
                    $memory_fd, $section_key,
                    $section_title,$full_destination
                )if length $section_title;

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

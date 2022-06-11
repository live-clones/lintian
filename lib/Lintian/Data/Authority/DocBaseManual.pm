# -*- perl -*-
#
# Copyright (C) 1998 Christian Schwarz and Richard Braakman
# Copyright (C) 2001 Colin Watson
# Copyright (C) 2008 Jordà Polo
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

package Lintian::Data::Authority::DocBaseManual;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Const::Fast;
use File::Basename qw(dirname basename);
use IPC::Run3;
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);
use WWW::Mechanize ();

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

Lintian::Data::Authority::DocBaseManual - Lintian interface for manual references

=head1 SYNOPSIS

    use Lintian::Data::Authority::DocBaseManual;

=head1 DESCRIPTION

Lintian::Data::Authority::DocBaseManual provides a way to load data files for
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
    default => 'Doc-Base Manual'
);

has shorthand => (
    is => 'rw',
    default => 'doc-base-manual'
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
    my ($self, $archive, $port, $requested_path) = @_;

    my @installed_by;

    # find installable package
    for my $installable_architecture ('all', $port) {

        my $local_path
          = $archive->contents_gz('sid', 'main', $installable_architecture);

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

    # shipped as part of the doc-base installable
    my $shipped_base = 'usr/share/doc/doc-base/doc-base.html/';
    my $index_name = 'index.html';

    my $shipped_path = $shipped_base . $index_name;
    my $stored_uri = "file:///$shipped_path";

    # neutral sort order
    local $ENV{LC_ALL} = 'C';

    my $port = 'amd64';
    my $installable_name
      = $self->find_installable_name($archive, $port, $shipped_path);

    my $deb822_by_installable_name
      = $archive->deb822_packages_by_installable_name('sid', 'main', $port);

    my $work_folder
      = Path::Tiny->tempdir(TEMPLATE => 'refresh-doc-base-manual-XXXXXXXXXX');

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
      or die encode_utf8('Cannot open scalar');

    my $mechanize = WWW::Mechanize->new();

    my $fresh_uri = URI::file->new_abs("/$extract_folder/$shipped_path");
    $mechanize->get($fresh_uri);

    my $page_title = $mechanize->title;

    # strip explanatory remark
    $page_title =~ s{ \s* \N{EM DASH} .* $}{}x;

    # underscore is a token for the whole page
    write_line($memory_fd, $VOLUME_KEY, $page_title, $stored_uri);

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

        my $destination_base = $stored_uri;
        $destination_base = dirname($stored_uri) . $SLASH
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

        write_line($memory_fd, $section_key, $section_title,$full_destination);
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

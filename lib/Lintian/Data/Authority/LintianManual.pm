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

package Lintian::Data::Authority::LintianManual;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Const::Fast;
use IPC::Run3;
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);
use URI::file;
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

const my $WAIT_STATUS_SHIFT => 8;

use Moo;
use namespace::clean;

with 'Lintian::Data::JoinedLines';

=head1 NAME

Lintian::Data::Authority::LintianManual - Lintian interface for manual references

=head1 SYNOPSIS

    use Lintian::Data::Authority::LintianManual;

=head1 DESCRIPTION

Lintian::Data::Authority::LintianManual provides a way to load data files for
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
    default => 'Lintian Manual'
);

has shorthand => (
    is => 'rw',
    default => 'lintian-manual'
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

=item refresh

=cut

sub refresh {
    my ($self, $archive, $basedir) = @_;

    # WWW::Mechanize will not parse page title without the suffix
    my $temp_tiny = Path::Tiny->tempfile(
        TEMPLATE => 'lintian-manual-XXXXXXXX',
        SUFFIX => '.html'
    );
    my $local_uri = URI::file->new_abs($temp_tiny->stringify);

    # for rst2html
    local $ENV{LC_ALL} = 'en_US.UTF-8';

    my $stderr;
    run3(['rst2html', "$ENV{LINTIAN_BASE}/doc/lintian.rst"],
        undef, $local_uri->file, \$stderr);
    my $status = ($? >> $WAIT_STATUS_SHIFT);

    # stderr already in UTF-8
    die $stderr
      if $status;

    my $generated;
    open(my $memory_fd, '>', \$generated)
      or die encode_utf8("Cannot open scalar: $!");

    my $page_url = 'https://lintian.debian.org/manual/index.html';

    my $mechanize = WWW::Mechanize->new();
    $mechanize->get($local_uri);

    my $page_title = $mechanize->title;

    # underscore is a token for the whole page
    write_line($memory_fd, $VOLUME_KEY, $page_title, $page_url);

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

        my $destination = $page_url . $link->url;

        next
          if exists $by_section_key{$section_key}
          && ( $by_section_key{$section_key}{title} eq $section_title
            || $by_section_key{$section_key}{destination} eq $destination);

        # Some manuals reuse section numbers for different references,
        # e.g. the Debian Policy's normal and appendix sections are
        # numbers that clash with each other. Track if we've already
        # seen a section pointing to some other URL than the current one,
        # and prepend it with an indicator
        $in_appendix = 1
          if exists $by_section_key{$section_key}
          && $by_section_key{$section_key}{destination} ne $destination;

        $section_key = "appendix-$section_key"
          if $in_appendix;

        $by_section_key{$section_key}{title} = $section_title;
        $by_section_key{$section_key}{destination} = $destination;

        write_line($memory_fd, $section_key, $section_title, $destination);
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

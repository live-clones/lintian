# files/source-missing -- lintian check script -*- perl -*-
#
# based on debhelper check,
# Copyright (C) 1999 Joey Hess
# Copyright (C) 2000 Sean 'Shaleh' Perry
# Copyright (C) 2002 Josip Rodin
# Copyright (C) 2007 Russ Allbery
# Copyright (C) 2013-2018 Bastien ROUCARIES
# Copyright (C) 2017-2020 Chris Lamb <lamby@debian.org>
# Copyright (C) 2020-2021 Felix Lechner
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, you can find it on the World Wide
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Files::SourceMissing;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Basename qw(basename);
use List::SomeUtils qw(first_value);
use List::UtilsBy qw(max_by);
use List::Util qw(max);
use Lintian::SlidingWindow;

# very long line lengths
const my $VERY_LONG_LINE_LENGTH => 512;

const my $EMPTY => q{};
const my $DOLLAR => q{$};
const my $DOT => q{.};
const my $DOUBLE_DOT => q{..};
const my $BLOCKSIZE => 16_384;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    # prebuilt-file or forbidden file type
    $self->pointed_hint('source-contains-prebuilt-wasm-binary', $item->pointer)
      if $item->file_type =~ m{^WebAssembly \s \(wasm\) \s binary \s module}x;

    $self->pointed_hint('source-contains-prebuilt-windows-binary',
        $item->pointer)
      if $item->file_type
      =~ m{\b(?:PE(?:32|64)|(?:MS-DOS|COM)\s executable)\b}x;

    $self->pointed_hint('source-contains-prebuilt-silverlight-object',
        $item->pointer)
      if $item->file_type =~ m{^Zip \s archive \s data}x
      && $item->name =~ m{(?i)\.xac$}x;

    if ($item->file_type =~ m{^python \s \d(\.\d+)? \s byte-compiled}x) {

        $self->pointed_hint('source-contains-prebuilt-python-object',
            $item->pointer);

        $self->pointed_hint('source-is-missing', $item->pointer)
          unless $self->find_source($item,
            {'.py' => '(?i)(?:\.cpython-\d{2}|\.pypy)?\.py[co]$'});
    }

    if ($item->file_type =~ m{\bELF\b}x) {
        $self->pointed_hint('source-contains-prebuilt-binary', $item->pointer);

        my %patterns = map {
            $_  =>
'(?i)(?:[\.-](?:bin|elf|e|hs|linux\d+|oo?|or|out|so(?:\.\d+)*)|static|_o\.golden)?$'
        } qw(.asm .c .cc .cpp .cxx .f .F .i .ml .rc .S);

        $self->pointed_hint('source-is-missing', $item->pointer)
          unless $self->find_source($item, \%patterns);
    }

    if ($item->file_type =~ m{^Macromedia \s Flash}x) {

        $self->pointed_hint('source-contains-prebuilt-flash-object',
            $item->pointer);

        $self->pointed_hint('source-is-missing', $item->pointer)
          unless $self->find_source($item, {'.as' => '(?i)\.swf$'});
    }

    if (   $item->file_type =~ m{^Composite \s Document \s File}x
        && $item->name =~ m{(?i)\.fla$}x) {

        $self->pointed_hint('source-contains-prebuilt-flash-project',
            $item->pointer);

        $self->pointed_hint('source-is-missing', $item->pointer)
          unless $self->find_source($item, {'.as' => '(?i)\.fla$'});
    }

    # see #745152
    # Be robust check also .js
    if ($item->basename eq 'deployJava.js') {
        if (
            lc $item->decoded_utf8
            =~ m/(?:\A|\v)\s*var\s+deployJava\s*=\s*function/xmsi) {

            $self->pointed_hint('source-is-missing', $item->pointer)
              unless $self->find_source($item,
                {'.txt' => '(?i)\.js$', $EMPTY => $EMPTY});

            return;
        }
    }

    # do not forget to change also $JS_EXT in file.pm
    if ($item->name
        =~ m{(?i)[-._](?:compiled|compressed|lite|min|pack(?:ed)?|prod|umd|yc)\.js$}x
    ) {

        $self->pointed_hint('source-contains-prebuilt-javascript-object',
            $item->pointer);
        my %patterns = map {
            $_ =>
'(?i)(?:[-._](?:compiled|compressed|lite|min|pack(?:ed)?|prod|umd|yc))?\.js$'
        } qw(.js _orig.js .js.orig .src.js -src.js .debug.js -debug.js -nc.js);

        $self->pointed_hint('source-is-missing', $item->pointer)
          unless $self->find_source($item, \%patterns);

        return;
    }

    open(my $fd, '<:raw', $item->unpacked_path)
      or die encode_utf8('Cannot open ' . $item->unpacked_path);
    my $sfd = Lintian::SlidingWindow->new;
    $sfd->handle($fd);
    $sfd->blocksize($BLOCKSIZE);
    my $longestl = -1;
    my $mostl = -1;

    while (my $block = $sfd->readwindow) {
        my @lines = split(/\n/, $item->bytes);
        my %line_length;
        my %semicolon_count;
        my $longest;
        my $most;

        my $position = 1;
        for my $line (@lines) {

            $line_length{$position} = length $line;
            $semicolon_count{$position} = ($line =~ tr/;/;/);

        } continue {
            ++$position;
        }

        $longest = max_by { $line_length{$_} } keys %line_length;
        $most = max_by { $semicolon_count{$_} } keys %semicolon_count;
        return if !defined $longest;
        $longestl = max($longestl,$line_length{$longest});
        $mostl = max($mostl,$line_length{$most});
    }
    return
      if $longestl <= $VERY_LONG_LINE_LENGTH;

    if ($item->basename =~ m{\.js$}i) {

        $self->pointed_hint('source-contains-prebuilt-javascript-object',
            $item->pointer);

        # Check for missing source.  It will check
        # for the source file in well known directories
        $self->pointed_hint('source-is-missing', $item->pointer)
          unless $self->find_source(
            $item,
            {
                '.debug.js' => '(?i)\.js$',
                '-debug.js' => '(?i)\.js$',
                $EMPTY => $EMPTY
            }
          );
    }

    if ($item->basename =~ /\.(?:x?html?\d?|xht)$/i) {

        # html file
        $self->pointed_hint('source-is-missing', $item->pointer)
          unless $self->find_source($item, {'.fragment.js' => $DOLLAR});
    }

    return;
}

sub find_source {
    my ($self, $item, $patternref) = @_;

    $patternref //= {};

    return undef
      unless $item->is_regular_file;

    return undef
      if $self->processable->is_non_free;

    my %patterns = %{$patternref};

    my @alternatives;
    for my $replacement (keys %patterns) {

        my $newname = $item->basename;

        # empty pattern would repeat the last regex compiled
        my $pattern = $patterns{$replacement};
        $newname =~ s/$pattern/$replacement/
          if length $pattern;

        push(@alternatives, $newname)
          if length $newname;
    }

    my $index = $self->processable->patched;
    my @candidates;

    # add standard locations
    push(@candidates,
        $index->resolve_path('debian/missing-sources/' . $item->name));
    push(@candidates,
        $index->resolve_path('debian/missing-sources/' . $item->basename));

    my $dirname = $item->dirname;
    my $parentname = basename($dirname);

    my @absolute = (
        # libtool
        '.libs',
        ".libs/$dirname",
        # mathjax
        'unpacked',
        # for missing source set in debian
        'debian',
        'debian/missing-sources',
        "debian/missing-sources/$dirname"
    );

    for my $absolute (@absolute) {
        push(@candidates, $index->resolve_path("$absolute/$_"))
          for @alternatives;
    }

    my @relative = (
        # likely in current dir
        $DOT,
        # for binary object built by libtool
        $DOUBLE_DOT,
        # maybe in src subdir
        './src',
        # maybe in ../src subdir
        '../src',
        "../../src/$parentname",
        # emscripten
        './flash-src/src/net/gimite/websocket',
    );

    for my $relative (@relative) {
        push(@candidates, $item->resolve_path("$relative/$_"))
          for @alternatives;
    }

    my @found = grep { defined } @candidates;

    # careful with behavior around empty arrays
    my $source = first_value { $_->name ne $item->name } @found;

    return $source;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

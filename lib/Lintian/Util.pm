# Hey emacs! This is a -*- Perl -*- script!
# Lintian::Util -- Perl utility functions for lintian

# Copyright © 1998 Christian Schwarz
# Copyright © 2018-2019 Chris Lamb <lamby@debian.org>
# Copyright © 2020 Felix Lechner
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
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Util;

use v5.20;
use warnings;
use utf8;

use Exporter qw(import);

# Force export as soon as possible, since some of the modules we load also
# depend on us and the sequencing can cause things not to be exported
# otherwise.
our @EXPORT_OK;

BEGIN {

    @EXPORT_OK = (qw(
          get_file_checksum
          get_file_digest
          human_bytes
          perm2oct
          locate_executable
          normalize_pkg_path
          normalize_link_target
          is_ancestor_of
          drain_pipe
          drop_relative_prefix
          read_md5sums
          utf8_clean_log
          utf8_clean_bytes
          version_from_changelog
          $PKGNAME_REGEX
          $PKGREPACK_REGEX
          $PKGVERSION_REGEX
    ));
}

use Carp qw(croak);
use Const::Fast;
use Cwd qw(abs_path);
use Digest::MD5;
use Digest::SHA;
use List::SomeUtils qw(first_value);
use Path::Tiny;
use Unicode::UTF8 qw(valid_utf8 encode_utf8);

use Lintian::Deb822::File;
use Lintian::Inspect::Changelog;
use Lintian::Relation::Version qw(versions_equal versions_comparator);

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $NEWLINE => qq{\n};
const my $SLASH => q{/};
const my $DOT => q{.};
const my $DOUBLEDOT => q{..};
const my $BACKSLASH => q{\\};

const my $DEFAULT_READ_SIZE => 4096;
const my $KIB_UNIT_FACTOR => 1024;
const my $COMFORT_THRESHOLD => 1536;

const my $OWNER_READ => oct(400);
const my $OWNER_WRITE => oct(200);
const my $OWNER_EXECUTE => oct(100);
const my $SETUID => oct(4000);
const my $SETUID_OWNER_EXECUTE => oct(4100);
const my $GROUP_READ => oct(40);
const my $GROUP_WRITE => oct(20);
const my $GROUP_EXECUTE => oct(10);
const my $SETGID => oct(2000);
const my $SETGID_GROUP_EXECUTE => oct(2010);
const my $WORLD_READ => oct(4);
const my $WORLD_WRITE => oct(2);
const my $WORLD_EXECUTE => oct(1);
const my $STICKY => oct(1000);
const my $STICKY_WORLD_EXECUTE => oct(1001);

# preload cache for common permission strings
# call overhead o perm2oct was measurable on chromium-browser/32.0.1700.123-2
# load time went from ~1.5s to ~0.1s; of 115363 paths, only 306 were uncached
# standard file, executable file, standard dir, dir with suid, symlink
my %OCTAL_LOOKUP = map { $_ => perm2oct($_) } qw(
  -rw-r--r--
  -rwxr-xr-x
  drwxr-xr-x
  drwxr-sr-x
  lrwxrwxrwx
);

=head1 NAME

Lintian::Util - Lintian utility functions

=head1 SYNOPSIS

 use Lintian::Util;

=head1 DESCRIPTION

This module contains a number of utility subs that are nice to have,
but on their own did not warrant their own module.

Most subs are imported only on request.

=head1 VARIABLES

=over 4

=item $PKGNAME_REGEX

Regular expression that matches valid package names.  The expression
is not anchored and does not enforce any "boundary" characters.

=cut

our $PKGNAME_REGEX = qr/[a-z0-9][-+\.a-z0-9]+/;

=item $PKGREPACK_REGEX

Regular expression that matches "repacked" package names.  The expression is
not anchored and does not enforce any "boundary" characters. It should only
be applied to the upstream portion (see #931846).

=cut

our $PKGREPACK_REGEX = qr/(dfsg|debian|ds|repack)/;

=item $PKGVERSION_REGEX

Regular expression that matches valid package versions.  The
expression is not anchored and does not enforce any "boundary"
characters.

=cut

our $PKGVERSION_REGEX = qr{
                 (?: \d+ : )?                # Optional epoch
                 [0-9][0-9A-Za-z.+:~]*       # Upstream version (with no hyphens)
                 (?: - [0-9A-Za-z.+:~]+ )*   # Optional debian revision (+ upstreams versions with hyphens)
                          }xa;

=back

=head1 FUNCTIONS

=over 4

=item drain_pipe(FD)

Reads and discards any remaining contents from FD, which is assumed to
be a pipe.  This is mostly done to avoid having the "write"-end die
with a SIGPIPE due to a "broken pipe" (which can happen if you just
close the pipe).

May cause an exception if there are issues reading from the pipe.

Caveat: This will block until the pipe is closed from the "write"-end,
so only use it with pipes where the "write"-end will eventually close
their end by themselves (or something else will make them close it).

=cut

sub drain_pipe {
    my ($fd) = @_;
    my $buffer;

    1 while (read($fd, $buffer, $DEFAULT_READ_SIZE) > 0);

    return 1;
}

=item get_file_digest(ALGO, FILE)

Creates an ALGO digest object that is seeded with the contents of
FILE.  If you just want the hex digest, please use
L</get_file_checksum(ALGO, FILE)> instead.

ALGO can be 'md5' or shaX, where X is any number supported by
L<Digest::SHA> (e.g. 'sha256').

This sub is a convenience wrapper around Digest::{MD5,SHA}.

=cut

sub get_file_digest {
    my ($alg, $file) = @_;

    open(my $fd, '<', $file)
      or die encode_utf8("Cannot open $file");

    my $digest;
    if (lc($alg) eq 'md5') {
        $digest = Digest::MD5->new;
    } elsif (lc($alg) =~ /sha(\d+)/) {
        $digest = Digest::SHA->new($1);
    }
    $digest->addfile($fd);
    close($fd);

    return $digest;
}

=item get_file_checksum(ALGO, FILE)

Returns a hexadecimal string of the message digest checksum generated
by the algorithm ALGO on FILE.

ALGO can be 'md5' or shaX, where X is any number supported by
L<Digest::SHA> (e.g. 'sha256').

This sub is a convenience wrapper around Digest::{MD5,SHA}.

=cut

sub get_file_checksum {
    my @paths = @_;

    my $digest = get_file_digest(@paths);

    return $digest->hexdigest;
}

=item perm2oct(PERM)

Translates PERM to an octal permission.  PERM should be a string describing
the permissions as done by I<tar t> or I<ls -l>.  That is, it should be a
string like "-rw-r--r--".

If the string does not appear to be a valid permission, it will cause
a trappable error.

Examples:

 # Good
 perm2oct('-rw-r--r--') == oct(644)
 perm2oct('-rwxr-xr-x') == oct(755)

 # Bad
 perm2oct('broken')      # too short to be recognised
 perm2oct('-resurunet')  # contains unknown permissions

=cut

sub perm2oct {
    my ($text) = @_;

    my $lookup = $OCTAL_LOOKUP{$text};
    return $lookup
      if defined $lookup;

    my $octal = 0;

    # Types:
    #  file (-), block/character device (b & c), directory (d),
    #  hardlink (h), symlink (l), named pipe (p).
    if (
        $text !~ m{^   [-bcdhlp]                # file type
                    ([-r])([-w])([-xsS])     # user
                    ([-r])([-w])([-xsS])     # group
                    ([-r])([-w])([-xtT])     # other
               }xsm
    ) {
        croak encode_utf8("$text does not appear to be a permission string");
    }

    $octal |= $OWNER_READ if $1 eq 'r';
    $octal |= $OWNER_WRITE if $2 eq 'w';
    $octal |= $OWNER_EXECUTE if $3 eq 'x';
    $octal |= $SETUID if $3 eq 'S';
    $octal |= $SETUID_OWNER_EXECUTE if $3 eq 's';
    $octal |= $GROUP_READ if $4 eq 'r';
    $octal |= $GROUP_WRITE if $5 eq 'w';
    $octal |= $GROUP_EXECUTE if $6 eq 'x';
    $octal |= $SETGID if $6 eq 'S';
    $octal |= $SETGID_GROUP_EXECUTE if $6 eq 's';
    $octal |= $WORLD_READ if $7 eq 'r';
    $octal |= $WORLD_WRITE if $8 eq 'w';
    $octal |= $WORLD_EXECUTE if $9 eq 'x';
    $octal |= $STICKY if $9 eq 'T';
    $octal |= $STICKY_WORLD_EXECUTE if $9 eq 't';

    $OCTAL_LOOKUP{$text} = $octal;

    return $octal;
}

=item human_bytes(SIZE)

=cut

sub human_bytes {
    my ($size) = @_;

    my @units = qw(B kiB MiB GiB);

    my $unit = shift @units;

    while ($size > $COMFORT_THRESHOLD && @units) {

        $size /= $KIB_UNIT_FACTOR;
        $unit = shift @units;
    }

    my $human = sprintf('%.0f %s', $size, $unit);

    return $human;
}

=item locate_executable (CMD)

=cut

sub locate_executable {
    my ($command) = @_;

    return $EMPTY
      unless exists $ENV{PATH};

    my @folders =  grep { length } split(/:/, $ENV{PATH});
    my $path = first_value { -x "$_/$command" } @folders;

    return ($path // $EMPTY);
}

=item drop_relative_prefix(STRING)

Remove an initial ./ from STRING, if present

=cut

sub drop_relative_prefix {
    my ($name) = @_;

    my $copy = $name;
    $copy =~ s{^\./}{}s;

    return $copy;
}

=item version_from_changelog

=cut

sub version_from_changelog {
    my ($package_path) = @_;

    my $changelog_path = "$package_path/debian/changelog";

    return $EMPTY
      unless -e $changelog_path;

    my $contents = path($changelog_path)->slurp_utf8;
    my $changelog = Lintian::Inspect::Changelog->new;

    $changelog->parse($contents);
    my @entries = @{$changelog->entries};

    return $entries[0]->{'Version'}
      if @entries;

    return $EMPTY;
}

=item normalize_pkg_path(PATH)

Normalize PATH by removing superfluous path segments.  PATH is assumed
to be relative the package root.  Note that the result will never
start nor end with a slash, even if PATH does.

As the name suggests, this is a path "normalization" rather than a
true path resolution (for that use Cwd::realpath).  Particularly,
it assumes none of the path segments are symlinks.

normalize_pkg_path will return C<q{}> (i.e. the empty string) if PATH
is normalized to the root dir and C<undef> if the path cannot be
normalized without escaping the package root.

=item normalize_link_target(CURDIR, LINK_TARGET)

Normalize the path obtained by following a link with LINK_TARGET as
its target from CURDIR as the current directory.  CURDIR is assumed to
be relative to the package root.  Note that the result will never
start nor end with a slash, even if CURDIR or DEST does.

normalize_pkg_path will return C<q{}> (i.e. the empty string) if the
target is the root dir and C<undef> if the path cannot be normalized
without escaping the package root.

B<CAVEAT>: This function is I<not always sufficient> to test if it is
safe to open a given symlink. Use C<is_ancestor_of(PARENTDIR, PATH)> for
that.  If you must use this function, remember to check that the
target is not a symlink (or if it is, that it can be resolved safely).

=cut

sub normalize_link_target {
    my ($path, $target) = @_;

    if (substr($target, 0, 1) eq $SLASH) {
        # Link is absolute
        $path = $target;
    } else {
        # link is relative
        $path = "$path/$target";
    }

    return normalize_pkg_path($path);
}

sub normalize_pkg_path {
    my ($path) = @_;

    return $EMPTY
      if $path eq $SLASH;

    my @dirty = split(m{/}, $path);
    my @clean = grep { length } @dirty;

    my @final;
    for my $component (@clean) {

        if ($component eq $DOT) {
            # do nothing

        } elsif ($component eq $DOUBLEDOT) {
            # are we out of bounds?
            my $discard = pop @final;
            return undef
              unless defined $discard;

        } else {
            push(@final, $component);
        }
    }

    # empty if we end in the root
    my $normalized = join($SLASH, @final);

    return $normalized;
}

=item is_ancestor_of(PARENTDIR, PATH)

Returns true if and only if PATH is PARENTDIR or a path stored
somewhere within PARENTDIR (or its subdirs).

This function will resolve the paths; any failure to resolve the path
will cause a trappable error.

=cut

sub is_ancestor_of {
    my ($ancestor, $file) = @_;

    my $resolved_file = abs_path($file);
    croak encode_utf8("resolving $file failed: $!")
      unless defined $resolved_file;

    my $resolved_ancestor = abs_path($ancestor);
    croak encode_utf8("resolving $ancestor failed: $!")
      unless defined $resolved_ancestor;

    my $len;
    return 1 if $resolved_ancestor eq $resolved_file;
    # add a slash, "path/some-dir" is not "path/some-dir-2" and this
    # allows us to blindly match against the root dir.
    $resolved_file .= $SLASH;
    $resolved_ancestor .= $SLASH;

    # If $resolved_file is contained within $resolved_ancestor, then
    # $resolved_ancestor will be a prefix of $resolved_file.
    $len = length($resolved_ancestor);
    if (substr($resolved_file, 0, $len) eq $resolved_ancestor) {
        return 1;
    }
    return 0;
}

=item read_md5sums

=item unescape_md5sum_filename

=cut

sub unescape_md5sum_filename {
    my ($string, $problematic) = @_;

    # done if there are no escapes
    return $string
      unless $problematic;

    # split into individual characters
    my @array = split(//, $string);

# https://www.gnu.org/software/coreutils/manual/html_node/md5sum-invocation.html
    my $path;
    my $escaped = 0;
    for my $char (@array) {

        # start escape sequence
        if ($char eq $BACKSLASH && !$escaped) {
            $escaped = 1;
            next;
        }

        # unescape newline
        $char = $NEWLINE
          if $char eq 'n' && $escaped;

        # append character
        $path .= $char;

        # end any escape sequence
        $escaped = 0;
    }

    # do not stop inside an escape sequence
    die encode_utf8('Name terminated inside an escape sequence')
      if $escaped;

    return $path;
}

sub read_md5sums {
    my ($text) = @_;

    my %checksums;
    my @errors;

    my @lines = split(/\n/, $text);

    while (defined(my $line = shift @lines)) {

        next
          unless length $line;

        # make sure there are two spaces in between
        $line =~ /^((?:\\)?\S{32})  (.*)$/;

        my $checksum = $1;
        my $string = $2;

        unless (length $checksum && length $string) {

            push(@errors, "Odd text: $line");
            next;
        }

        my $problematic = 0;

        # leading slash in checksum indicates an escaped name
        $problematic = 1
          if $checksum =~ s{^\\}{};

        my $path = unescape_md5sum_filename($string, $problematic);

        push(@errors, "Empty name for checksum $checksum")
          unless length $path;

        $checksums{$path} = $checksum;
    }

    return (\%checksums, \@errors);
}

=item utf8_clean_log

=cut

sub utf8_clean_log {
    my ($bytes) = @_;

    my $hex_sequence = sub {
        my ($unclean_bytes) = @_;
        return '{hex:' . sprintf('%vX', $unclean_bytes) . '}';
    };

    my $utf8_clean_word = sub {
        my ($word) = @_;
        return utf8_clean_bytes($word, $SLASH, $hex_sequence);
    };

    my $utf8_clean_line = sub {
        my ($line) = @_;
        return utf8_clean_bytes($line, $SPACE, $utf8_clean_word);
    };

    return utf8_clean_bytes($bytes, $NEWLINE, $utf8_clean_line) . $NEWLINE;
}

=item utf8_clean_bytes

=cut

sub utf8_clean_bytes {
    my ($bytes, $separator, $utf8_clean_part) = @_;

    my @utf8_clean_parts;

    my $regex = quotemeta($separator);
    my @parts = split(/$regex/, $bytes);

    for my $part (@parts) {

        if (valid_utf8($part)) {
            push(@utf8_clean_parts, $part);

        } else {
            push(@utf8_clean_parts, $utf8_clean_part->($part));
        }
    }

    return join($separator, @utf8_clean_parts);
}

=back

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

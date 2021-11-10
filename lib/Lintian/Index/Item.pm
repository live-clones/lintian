# -*- perl -*-
# Lintian::Index::Item -- Representation of path entry in a package
#
# Copyright © 2011 Niels Thykier
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

package Lintian::Index::Item;

use v5.20;
use warnings;
use utf8;
use autodie qw(open);

use Carp qw(croak confess);
use Const::Fast;
use Date::Parse qw(str2time);
use List::SomeUtils qw(all);
use Path::Tiny;
use Text::Balanced qw(extract_delimited);
use Unicode::UTF8 qw(valid_utf8 decode_utf8 encode_utf8);

use Lintian::SlidingWindow;
use Lintian::Util qw(normalize_link_target);

use Moo;
use namespace::clean;

use constant {
    TYPE_FILE      => 0x00_01_00_00,
    TYPE_HARDLINK  => 0x00_02_00_00,
    TYPE_DIR       => 0x00_04_00_00,
    TYPE_SYMLINK   => 0x00_08_00_00,
    TYPE_BLOCK_DEV => 0x00_10_00_00,
    TYPE_CHAR_DEV  => 0x00_20_00_00,
    TYPE_PIPE      => 0x00_40_00_00,
    TYPE_OTHER     => 0x00_80_00_00,
    TYPE_MASK      => 0x00_ff_00_00,

    UNSAFE_PATH    => 0x01_00_00_00,
    FS_PATH_IS_OK  => 0x02_00_00_00,
    OPEN_IS_OK     => 0x06_00_00_00, # Implies FS_PATH_IS_OK
    ACCESS_INFO    => 0x07_00_00_00,
    # 0o6777 == 0xdff, which covers set[ug]id + sticky bit.  Accordingly,
    # 0xffff should be more than sufficient for the foreseeable future.
    OPERM_MASK     => 0x00_00_ff_ff,
};

use overload (
    q{""} => \&_as_string,
    'qr' => \&_as_regex_ref,
    'bool' => \&_bool,
    q{!} => \&_bool_not,
    q{.} => \&_str_concat,
    'cmp' => \&_str_cmp,
    'eq' => \&_str_eq,
    'ne' => \&_str_ne,
    'fallback' => 0,
);

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $SLASH => q{/};
const my $DOT => q{.};
const my $DOUBLE_DOT => q{..};
const my $DOUBLE_QUOTE => q{"};
const my $BACKSLASH => q{\\};
const my $HASHBANG => q{#!};

const my $MAXIMUM_LINK_DEPTH => 18;

const my $BYTE_MAXIMUM => 255;
const my $SINGLE_OCTAL_MASK => oct(7);
const my $DUAL_OCTAL_MASK => oct(77);

const my $ELF_MAGIC_SIZE => 4;
const my $LINCITY_MAGIC_SIZE => 6;
const my $SHELL_SCRIPT_MAGIC_SIZE => 2;

const my $READ_BITS => oct(444);
const my $WRITE_BITS => oct(222);
const my $EXECUTABLE_BITS => oct(111);

const my $SETUID => oct(4000);
const my $SETGID => oct(2000);

=head1 NAME

Lintian::Index::Item - Lintian representation of a path entry in a package

=head1 SYNOPSIS

    my ($name, $type, $dir) = ('lintian', 'source', '/path/to/entry');

=head1 INSTANCE METHODS

=over 4

=item init_from_tar_output

=item get_quoted_filename

=item unescape_c_style

=cut

my $datepattern = qr/\d{4}-\d{2}-\d{2}/;
my $timepattern = qr/\d{2}\:\d{2}(?:\:\d{2}(?:\.\d+)?)?/;
my $symlinkpattern = qr/\s+->\s+/;
my $hardlinkpattern = qr/\s+link\s+to\s+/;

# adapted from https://www.perlmonks.org/?node_id=1056606
my %T = (
    (map {chr() => chr} 0..$BYTE_MAXIMUM),
    (map {sprintf('%o',$_) => chr} 0..($BYTE_MAXIMUM & $SINGLE_OCTAL_MASK)),
    (map {sprintf('%02o',$_) => chr} 0..($BYTE_MAXIMUM & $DUAL_OCTAL_MASK)),
    (map {sprintf('%03o',$_) => chr} 0..$BYTE_MAXIMUM),
    (split //, "r\rn\nb\ba\af\ft\tv\013"));

sub unescape_c_style {
    my ($escaped) = @_;

    (my $result = $escaped) =~ s/\\([0-7]{1,3}|.)/$T{$1}/g;

    return $result;
}

sub get_quoted_filename {
    my ($unknown, $skip) = @_;

    # extract quoted file name
    my ($delimited, $extra)
      = extract_delimited($unknown, $DOUBLE_QUOTE, $skip, $BACKSLASH);

    return (undef, undef)
      unless defined $delimited;

    # drop quotes
    my $cstylename = substr($delimited, 1, (length $delimited) - 2);

    # convert c-style escapes
    my $name = unescape_c_style($cstylename);

    return ($name, $extra);
}

sub init_from_tar_output {
    my ($self, $line) = @_;

    chomp $line;

    # allow spaces in ownership and filenames (#895175 and #950589)

    my ($initial, $size, $date, $time, $remainder)
      = split(/\s+(\d+)\s+($datepattern)\s+($timepattern)\s+/, $line,2);

    die encode_utf8("Cannot parse tar output: $line")
      unless all { defined } ($initial, $size, $date, $time, $remainder);

    $self->size($size);
    $self->date($date);
    $self->time($time);

    my ($permissions, $ownership) = split(/\s+/, $initial, 2);
    die encode_utf8(
        "Cannot parse permissions and ownership in tar output: $line")
      unless all { defined } ($permissions, $ownership);

    $self->perm($permissions);

    my ($owner, $group) = split(qr{/}, $ownership, 2);
    die encode_utf8("Cannot parse owner and group in tar output: $line")
      unless all { defined } ($owner, $group);

    $self->owner($owner);
    $self->group($group);

    my ($name, $extra) = get_quoted_filename($remainder, $EMPTY);
    die encode_utf8("Cannot parse file name in tar output: $line")
      unless all { defined } ($name, $extra);

    # strip relative prefix
    $name =~ s{^\./+}{}s;

    # slashes cannot appear in names but are sometimes doubled
    # as in emboss-explorer_2.2.0-10.dsc
    # better implemented in a Moo trigger on the attribute
    $name =~ s{/+}{/}g;

    # make sure directories end with a slash, except root
    $name .= $SLASH
      if length $name
      && $self->perm =~ / ^d /msx
      && $name !~ m{ /$ }msx;

    $self->name($name);

    # look for symbolic link target
    if ($self->perm =~ /^l/) {

        my ($linktarget, undef) = get_quoted_filename($extra, $symlinkpattern);
        die encode_utf8(
            "Cannot parse symbolic link target in tar output: $line")
          unless defined $linktarget;

        # do not remove multiple slashes from symlink targets
        # caught by symlink-has-double-slash, which is tested
        # leaves resolution of these links unsolved

        # do not strip relative prefix for symbolic links
        $self->link($linktarget);
    }

    # look for hard link target
    if ($self->perm =~ /^h/) {

        my ($linktarget, undef)= get_quoted_filename($extra, $hardlinkpattern);
        die encode_utf8("Cannot parse hard link target in tar output: $line")
          unless defined $linktarget;

        # strip relative prefix
        $linktarget =~ s{^\./+}{}s;

        # slashes cannot appear in names but are sometimes doubled
        # as in emboss-explorer_2.2.0-10.dsc
        # better implemented in a Moo trigger on the attribute, but requires
        # separate attributes for hard and symbolic link targets
        $linktarget =~ s{/+}{/}g;

        $self->link($linktarget);
    }

    return;
}

=item bytes_match(REGEX)

Returns the matched string if REGEX matches the file's byte contents,
or $EMPTY otherwise.

=cut

sub bytes_match {
    my ($self, $regex) = @_;

    return $EMPTY
      unless $self->is_file;

    return $EMPTY
      unless $self->is_open_ok;

    return $EMPTY
      unless length $regex;

    open(my $fd, '<:raw', $self->unpacked_path);
    my $sfd = Lintian::SlidingWindow->new;
    $sfd->handle($fd);

    my $match;
    while (my $block = $sfd->readwindow) {

        if ($block =~ /($regex)/) {

            $match = $1;
            last;
        }
    }

    close $fd;

    return $match // $EMPTY;
}

=item mentions_in_operation(REGEX)

Returns the matched string if REGEX matches in a file location
that is likely an operation (vs text), or $EMPTY otherwise.

=cut

sub mentions_in_operation {
    my ($self, $regex) = @_;

    # prefer strings(1) output (eg. for ELF) if we have it
    # may not work as expected on ELF due to ld's SHF_MERGE
    my $match;
    if (length $self->strings && $self->strings =~ /($regex)/) {
        $match = $1;

    } elsif ($self->is_script) {
        $match = $self->bytes_match($regex);
    }

    return $match // $EMPTY;
}

=item magic(COUNT)

Returns the specified COUNT of magic bytes for the file.

=cut

sub magic {
    my ($self, $count) = @_;

    return $EMPTY
      if length $self->link;

    return $EMPTY
      if $self->size < $count;

    return $EMPTY
      unless $self->is_open_ok;

    my $magic;

    open(my $fd, '<', $self->unpacked_path);
    die encode_utf8("Could not read $count bytes from " . $self->name)
      unless read($fd, $magic, $count) == $count;
    close $fd;

    return $magic;
}

=item C<hashbang>

Returns the C<hashbang> for the file if it is a script.

=cut

has hashbang => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $EMPTY
          unless $self->is_script;

        my $trimmed_bytes = $EMPTY;
        my $magic;

        open(my $fd, '<', $self->unpacked_path);
        if (read($fd, $magic, 2) && $magic eq $HASHBANG && !eof($fd)) {
            $trimmed_bytes = <$fd>;
        }
        close $fd;

        # decoding UTF-8 fails on magyarispell_1.6.1-2.dsc and ldc_1.24.0-1.dsc

        # remove comment, if any
        $trimmed_bytes =~ s/^([^#]*)/$1/;

        # trim both ends
        $trimmed_bytes =~ s/^\s+|\s+$//g;

        return $trimmed_bytes;
    });

=item interpreter_with_options

Returns the interpreter requested by a script with options
after stripping C<env>.

=cut

has interpreter_with_options => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $with_options = $self->hashbang;

        $with_options =~ s{^/usr/bin/env\s+}{};

        return $with_options;
    });

=item interpreter

Returns the interpreter requested by a script but strips C<env>.

=cut

has interpreter => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $interpreter = $self->interpreter_with_options;

        # keep base command without options
        $interpreter =~ s/^(\S+).*/$1/;

        return $interpreter;
    });

=item C<calls_env>

Returns true if file is a script that calls C<env>.

=cut

has calls_env => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        # must return a boolean success value #943724
        return 1
          if $self->hashbang =~ m{^/usr/bin/env\s+};

        return 0;
    });

=item C<is_shell_script>

Returns true if file is a script requesting a recognized shell
interpreter.

=cut

has is_shell_script => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $interpreter = $self->interpreter;

        # keep basename
        my ($basename) = ($interpreter =~ m{([^/]*)/?$}s);

        return 1
          if $basename =~ /^(?:[bd]?a|t?c|(?:pd|m)?k|z)?sh$/;

        return 0;
    });

=item is_elf

Returns true if file is an ELF executable, and false otherwise.

=cut

has is_elf => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return 1
          if $self->magic($ELF_MAGIC_SIZE) eq "\x7FELF";

        return 0;
    });

=item is_script

Returns true if file is a script and false otherwise.

=cut

has is_script => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        # skip lincity data files; magic: #!#!#!
        return 0
          if $self->magic($LINCITY_MAGIC_SIZE) eq '#!#!#!';

        return 0
          unless $self->magic($SHELL_SCRIPT_MAGIC_SIZE) eq $HASHBANG;

        return 1;
    });

=item is_maintainer_script

Returns true if file is a maintainer script and false otherwise.

=cut

has is_maintainer_script => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return 1
          if $self->name =~ /^ config | (?:pre|post)(?:inst|rm) $/x
          && $self->is_open_ok;

        return 0;
    });

=item identity

Returns the owner and group of the path, separated by a slash.

NB: If only numerical owner information is available in the package,
this may return a numerical owner (except uid 0 is always mapped to
"root")

=cut

sub identity {
    my ($self) = @_;

    return $self->owner . $SLASH . $self->group;
}

=item operm

Returns the file permissions of this object in octal (e.g. 0644).

NB: This is only well defined for file entries that are subject to
permissions (e.g. files).  Particularly, the value is not well defined
for symlinks.

=cut

sub operm {
    my ($self) = @_;

    return $self->path_info & OPERM_MASK;
}

=item octal_permissions

=cut

sub octal_permissions {
    my ($self) = @_;

    return sprintf('%04o', $self->operm);
}

=item children

Returns a list of children (as Lintian::File::Path objects) of this entry.
The list and its contents should not be modified.

Only returns direct children of this directory.  The entries are sorted by name.

NB: Returns the empty list for non-dir entries.

=cut

sub children {
    my ($self) = @_;

    my @names = values %{$self->childnames};

    croak encode_utf8('No index in ' . $self->name)
      unless defined $self->index;

    return map { $self->index->lookup($_) } @names;
}

=item descendants

Returns a list of children (as Lintian::File::Path objects) of this entry.
The list and its contents should not be modified.

Descends recursively into subdirectories and return the descendants in
breadth-first order.  Children of a given directory will be sorted by
name.

NB: Returns the empty list for non-dir entries.

=cut

sub descendants {
    my ($self) = @_;

    my @descendants = $self->children;

    my @directories = grep { $_->is_dir } @descendants;
    push(@descendants, $_->descendants) for @directories;

    return @descendants;
}

=item timestamp

Returns a Unix timestamp for the given path. This is a number of
seconds since the start of Unix epoch in UTC.

=cut

sub timestamp {
    my ($self) = @_;

    my $timestamp = $self->date . $SPACE . $self->time;

    return str2time($timestamp, 'GMT');
}

=item child(BASENAME)

Returns the child named BASENAME if it is a child of this directory.
Otherwise, this method returns C<undef>.

Even for directories, BASENAME should not end with a slash.

When invoked on non-dirs, this method always returns C<undef>.

Example:

  $dir_entry->child('foo') => $entry OR undef

=cut

sub child {
    my ($self, $basename) = @_;

    croak encode_utf8('Basename is required')
      unless length $basename;

    my $childname = $self->childnames->{$basename};
    return undef
      unless $childname;

    croak encode_utf8('No index in ' . $self->name)
      unless defined $self->index;

    return $self->index->lookup($childname);
}

=item is_symlink

Returns a truth value if this entry is a symlink.

=item is_hardlink

Returns a truth value if this entry is a hardlink to a regular file.

NB: The target of a hardlink is always a regular file (and not a dir etc.).

=item is_dir

Returns a truth value if this entry is a dir.

NB: Unlike the "-d $dir" operator this will never return true for
symlinks, even if the symlink points to a dir.

=item is_file

Returns a truth value if this entry is a regular file (or a hardlink to one).

NB: Unlike the "-f $file" operator this will never return true for
symlinks, even if the symlink points to a file (or hardlink).

=item is_regular_file

Returns a truth value if this entry is a regular file.

This is eqv. to $path->is_file and not $path->is_hardlink.

NB: Unlike the "-f $file" operator this will never return true for
symlinks, even if the symlink points to a file.

=cut

sub is_symlink {
    my ($self) = @_;

    return $self->path_info & TYPE_SYMLINK ? 1 : 0;
}

sub is_hardlink {
    my ($self) = @_;

    return $self->path_info & TYPE_HARDLINK ? 1 : 0;
}

sub is_dir {
    my ($self) = @_;

    return $self->path_info & TYPE_DIR ? 1 : 0;
}

sub is_file {
    my ($self) = @_;

    return $self->path_info & (TYPE_FILE | TYPE_HARDLINK) ? 1 : 0;
}

sub is_regular_file {
    my ($self) = @_;

    return $self->path_info & TYPE_FILE ? 1 : 0;
}

=item link_normalized

Returns the target of the link normalized against it's directory name.
If the link cannot be normalized or normalized path might escape the
package root, this method returns C<undef>.

NB: This method will return the empty string for links pointing to the
root dir of the package.

Only available on "links" (i.e. symlinks or hardlinks).  On non-links
this will croak.

I<Symlinks only>: If you want the symlink target as a L<Lintian::File::Path>
object, use the L<resolve_path|/resolve_path([PATH])> method with no
arguments instead.

=cut

has link_normalized => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $name = $self->name;
        my $link = $self->link;

        croak encode_utf8("$name is not a link")
          unless length $link;

        my $dir = $self->dirname;

        # hardlinks are always relative to the package root
        $dir = $SLASH
          if $self->is_hardlink;

        my $target = normalize_link_target($dir, $link);

        return $target;
    });

=item is_readable

Returns a truth value if the permission bits of this entry have
at least one bit denoting readability set (bitmask 0444).

=item is_writable

Returns a truth value if the permission bits of this entry have
at least one bit denoting writability set (bitmask 0222).

=item is_executable

Returns a truth value if the permission bits of this entry have
at least one bit denoting executability set (bitmask 0111).

=cut

sub is_readable   {
    my ($self) = @_;

    return $self->path_info & $READ_BITS;
}

sub is_writable   {
    my ($self) = @_;

    return $self->path_info & $WRITE_BITS;
}

sub is_executable {
    my ($self) = @_;

    return $self->path_info & $EXECUTABLE_BITS;
}

=item all_bits_set

=cut

sub all_bits_set {
    my ($self, $bits) = @_;

    return ($self->operm & $bits) == $bits;
}

=item is_setuid

=cut

sub is_setuid {
    my ($self) = @_;

    return $self->operm & $SETUID;
}

=item is_setgid

=cut

sub is_setgid {
    my ($self) = @_;

    return $self->operm & $SETGID;
}

=item unpacked_path

Returns the path to this object on the file system, which must be a
regular file, a hardlink or a directory.

This method may fail if:

=over 4

=item * The object is neither a directory or a file-like object (e.g. a
named pipe).

=item * If the object is dangling symlink or the path traverses a symlink
outside the package root.

=back

To test if this is safe to call, if the target is (supposed) to be a:

=over 4

=item * file or hardlink then test with L</is_open_ok>.

=item * dir then assert L<resolve_path|/resolve_path([PATH])> returns a
defined entry, for which L</is_dir> returns a truth value.

=back

=cut

sub unpacked_path {
    my ($self) = @_;

    $self->_check_access;

    croak encode_utf8('No index in ' . $self->name)
      unless defined $self->index;

    my $basedir = $self->index->basedir;

    croak encode_utf8('No base directory')
      unless length $basedir;

    my $unpacked = path($basedir)->child($self->name)->stringify;

    # bug in perl, file operator should not care but does
    # https://github.com/Perl/perl5/issues/10550
    # also, https://github.com/Perl/perl5/issues/9674
    utf8::downgrade $unpacked;

    return $unpacked;
}

=item is_open_ok

Returns a truth value if it is safe to attempt open a read handle to
the underlying file object.

Returns a truth value if the path may be opened.

=cut

sub is_open_ok {
    my ($self) = @_;

    my $path_info = $self->path_info;

    return 1
      if ($path_info & OPEN_IS_OK) == OPEN_IS_OK;

    return 0
      if $path_info & ACCESS_INFO;

    eval {$self->_check_open;};

    return 0
      if $@;

    return 1;
}

sub _check_access {
    my ($self) = @_;

    my $path_info = $self->path_info;

    return 1
      if ($path_info & FS_PATH_IS_OK) == FS_PATH_IS_OK;

    return 0
      if $path_info & ACCESS_INFO;

    my $resolvable = $self->resolve_path;
    unless ($resolvable) {
        $self->path_info($self->path_info | UNSAFE_PATH);
        # NB: We are deliberately vague here to avoid suggesting
        # whether $path exists.  In some cases (e.g. lintian.d.o)
        # the output is readily available to wider public.
        confess encode_utf8(
            'Attempt to access through broken or unsafe symlink: '
              . $self->name);
    }

    $self->path_info($self->path_info | FS_PATH_IS_OK);

    return 1;
}

sub _check_open {
    my ($self) = @_;

    $self->_check_access;

    # Symlinks can point to a "non-file" object inside the
    # package root
    # Leave "_path_access" here as _check_access marks it either as
    # "UNSAFE_PATH" or "FS_PATH_IS_OK"

    confess encode_utf8(
        'Opening of irregular file not supported: ' . $self->name)
      unless $self->is_file || ($self->is_symlink && -e $self->unpacked_path);

    $self->path_info($self->path_info | OPEN_IS_OK);

    return 1;
}

=item follow

Return dereferenced link if applicable

=cut

sub follow {
    my ($self, $maxlinks) = @_;

    return $self
      unless length $self->link;

    return $self->dereferenced
      if defined $self->dereferenced;

    # set limit
    $maxlinks //= $MAXIMUM_LINK_DEPTH;

    # catch recursive links
    return undef
      if $maxlinks <= 0;

    # reduce counter
    $maxlinks--;

    my $reference;

    croak encode_utf8('No index in ' . $self->name)
      unless defined $self->index;

    if ($self->is_hardlink) {
        # hard links are resolved against package root
        $reference = $self->index->lookup;

    } else {
        # otherwise resolve against the parent
        $reference = $self->parent_dir;
    }

    croak encode_utf8('No parent reference for link in ' . $self->name)
      unless defined $reference;

    # follow link
    my $dereferenced = $reference->resolve_path($self->link, $maxlinks);
    $self->dereferenced($dereferenced);

    return $self->dereferenced;
}

=item resolve_path([PATH])

Resolve PATH relative to this path entry.

If PATH starts with a slash and the file hierarchy has a well-defined
root directory, then PATH will instead be resolved relatively to the
root dir.  If the file hierarchy does not have a well-defined root dir
(e.g. for source packages), this method will return C<undef>.

If PATH is omitted, then the entry is resolved and the target is
returned if it is valid.  Except for symlinks, all entries always
resolve to themselves.  NB: hardlinks also resolve as themselves.

It is an error to attempt to resolve a PATH against a non-directory
and non-symlink entry - as such resolution would always fail
(i.e. foo/../bar is an invalid path unless foo is a directory or a
symlink to a dir).


The resolution takes symlinks into account and following them provided
that the target path is valid (and can be followed safely).  If the
path is invalid or circular (symlinks), escapes the root directory or
follows an unsafe symlink, the method returns C<undef>.  Otherwise, it
returns the path entry that denotes the target path.


If PATH contains at least one path segment and ends with a slash, then
the resolved path will end in a directory (or fail).  Otherwise, the
resolved PATH can end in any entry I<except> a symlink.

Examples:

  $symlink_entry->resolve_path => $nonsymlink_entry OR undef

  $x->resolve_path => $x

  For directory or symlink entries (dol), you can also resolve a path:

  $dol_entry->resolve_path('some/../where') => $nonsymlink_entry OR undef

  # Note the trailing slash
  $dol_entry->resolve_path('some/../where/') => $dir_entry OR undef

=cut

sub resolve_path {
    my ($self, $request, $maxlinks) = @_;

    croak encode_utf8('Can only resolve string arguments')
      if defined $request && ref($request) ne $EMPTY;

    $request //= $EMPTY;

    croak encode_utf8('No index in ' . $self->name)
      unless defined $self->index;

    if (length $self->link) {
        # follow the link
        my $dereferenced = $self->follow($maxlinks);
        return undef
          unless defined $dereferenced;

        # and use that to resolve the request
        return $dereferenced->resolve_path($request, $maxlinks);
    }

    my $reference;

    # check for absolute reference; remove slash
    if ($request =~ s{^/+}{}s) {

        # require anchoring for absolute references
        return undef
          unless $self->index->anchored;

        # get root entry
        $reference = $self->index->lookup;

    } elsif ($self->is_dir) {
        # directories are their own starting point
        $reference = $self;

    } else {
        # otherwise, use parent directory
        $reference = $self->parent_dir;
    }

    return undef
      unless defined $reference;

    # read first segment; strip all trailing slashes for recursive use
    if ($request =~ s{^([^/]+)/*}{}) {

        my $segment = $1;

        # single dot, or two slashes in a row
        return $reference->resolve_path($request, $maxlinks)
          if $segment eq $DOT || !length $segment;

        # for double dot, go up a level
        if ($segment eq $DOUBLE_DOT) {
            my $parent = $reference->parent_dir;
            return undef
              unless defined $parent;

            return $parent->resolve_path($request, $maxlinks);
        }

        # look for child otherwise
        my $child = $reference->child($segment);
        return undef
          unless defined $child;

        return $child->resolve_path($request, $maxlinks);
    }

    croak encode_utf8("Cannot parse path resolution request: $request")
      if length $request;

    # nothing else to resolve
    return $self;
}

=item name

Returns the name of the file (relative to the package root).

NB: It will never have any leading "./" (or "/") in it.

=item basename

Returns the "filename" part of the name, similar basename(1) or
File::Basename::basename (without passing a suffix to strip in either
case).

NB: Returns the empty string for the "root" dir.

=item dirname

Returns the "directory" part of the name, similar to dirname(1) or
File::Basename::dirname.  The dirname will end with a trailing slash
(except the "root" dir - see below).

NB: Returns the empty string for the "root" dir.

=item link

If this is a link (i.e. is_symlink or is_hardlink returns a truth
value), this method returns the target of the link.

If this is not a link, then this returns undef.

If the path is a symlink this method can be used to determine if the
symlink is relative or absolute.  This is I<not> true for hardlinks,
where the link target is always relative to the root.

NB: Even for symlinks, a leading "./" will be stripped.

=item normalized

=item faux

Returns a truth value if this entry absent in the package.  This can
happen if a package does not include all intermediate directories.

=item size

Returns the size of the path in bytes.

NB: Only regular files can have a non-zero file size.

=item date

Return the modification date as YYYY-MM-DD.

=item time

=item perm

=item path_info

=item owner

Returns the owner of the path entry as a username.

NB: If only numerical owner information is available in the package,
this may return a numerical owner (except uid 0 is always mapped to
"root")

=item group

Returns the group of the path entry as a username.

NB: If only numerical owner information is available in the package,
this may return a numerical group (except gid 0 is always mapped to
"root")

=item uid

Returns the uid of the owner of the path entry.

NB: If the uid is not available, 0 will be returned.
This usually happens if the numerical data is not collected (e.g. in
source packages)

=item gid

Returns the gid of the owner of the path entry.

NB: If the gid is not available, 0 will be returned.
This usually happens if the numerical data is not collected (e.g. in
source packages)

=item file_info

Return the data from L<file(1)> if it has been collected.

Note this is only defined for files as Lintian only runs L<file(1)> on
files.

=item java_info

=item strings

=item elf

=item elf_by_member

=item C<basedir>

=item index

=item parent_dir

=item child_table

=item sorted_children

Returns the parent directory entry of this entry as a
L<Lintian::File::Path>.

NB: Returns C<undef> for the "root" dir.

=item C<childnames>

=item parent_dir

Return the parent dir entry of this the path entry.

=item dereferenced

=cut

has name => (
    is => 'rw',
    lazy => 1,
    coerce => sub { my ($string) = @_; return $string // $EMPTY;},
    trigger => sub {
        my ($self, $name) = @_;

        my ($basename) = ($name =~ m{([^/]*)/?$}s);
        $self->basename($basename);

        # allow newline in names; need /s for dot matching (#929729)
        my ($dirname) = ($name =~ m{^(.+/)?(?:[^/]+/?)$}s);
        $self->dirname($dirname);
    },
    default => $EMPTY
);
has basename => (
    is => 'rw',
    lazy => 1,
    coerce => sub { my ($string) = @_; return $string // $EMPTY;},
    default => $EMPTY
);
has dirname => (
    is => 'rw',
    lazy => 1,
    coerce => sub { my ($string) = @_; return $string // $EMPTY;},
    default => $EMPTY
);

has link => (
    is => 'rw',
    coerce => sub { my ($string) = @_; return $string // $EMPTY;},
    default => $EMPTY
);
has normalized => (
    is => 'rw',
    coerce => sub { my ($string) = @_; return $string // $EMPTY;},
    default => $EMPTY
);
has faux => (is => 'rw', default => 0);

has size => (is => 'rw', default => 0);
has date => (
    is => 'rw',
    default => sub {
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime;
        return sprintf('%04d-%02d-%02d', $year, $mon, $mday);
    });
has time => (
    is => 'rw',
    default => sub {
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime;
        return sprintf('%02d:%02d:%02d', $hour, $min, $sec);
    });

has perm => (is => 'rw');
has path_info => (is => 'rw');

has owner => (
    is => 'rw',
    coerce => sub { my ($string) = @_; return $string // 'root'; },
    default => 'root'
);
has group => (
    is => 'rw',
    coerce => sub { my ($string) = @_; return $string // 'root'; },
    default => 'root'
);
has uid => (
    is => 'rw',
    coerce => sub { my ($value) = @_; return int($value // 0); },
    default => 0
);
has gid => (
    is => 'rw',
    coerce => sub { my ($value) = @_; return int($value // 0); },
    default => 0
);

has md5sum => (
    is => 'rw',
    coerce => sub { my ($checksum) = @_; return ($checksum // 0); },
    default => 0
);
has file_info => (
    is => 'rw',
    coerce => sub { my ($text) = @_; return ($text // $EMPTY); },
    default => $EMPTY
);
has java_info => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });
has strings => (
    is => 'rw',
    coerce => sub { my ($text) = @_; return ($text // $EMPTY); },
    default => $EMPTY
);
has elf => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });
has elf_by_member => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });
has ar_info => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

has index => (is => 'rw');
has childnames => (is => 'rw', default => sub { {} });
has parent_dir => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        # do not return root as its own parent
        return
          if $self->name eq $EMPTY;

        croak encode_utf8('No index in ' . $self->name)
          unless defined $self->index;

        # returns root by default
        return $self->index->lookup($self->dirname);
    });
has dereferenced => (is => 'rw');

=item bytes

Returns verbatim file contents as a scalar.

=item is_valid_utf8

Boolean true if file contents are valid UTF-8.

=item decoded_utf8

Returns a decoded, wide-character string if file contents are valid UTF-8.

=cut

sub bytes {
    my ($self) = @_;

    return $EMPTY
      unless $self->is_open_ok;

    my $bytes = path($self->unpacked_path)->slurp;

    return $bytes;
}

sub is_valid_utf8 {
    my ($self) = @_;

    my $bytes = $self->bytes;
    return 0
      unless defined $bytes;

    return valid_utf8($bytes);
}

sub decoded_utf8 {
    my ($self) = @_;

    return $EMPTY
      unless $self->is_valid_utf8;

    return decode_utf8($self->bytes);
}

### OVERLOADED OPERATORS ###

# overload apparently does not like the mk_ro_accessor, so use a level
# of indirection

sub _as_regex_ref {
    my ($self) = @_;
    my $name = $self->name;
    return qr{ \Q$name\E }xsm;
}

sub _as_string {
    my ($self) = @_;
    return $self->name;
}

sub _bool {
    # Always true (used in "if ($info->index('some/path')) {...}")
    return 1;
}

sub _bool_not {
    my ($self) = @_;
    return !$self->_bool;
}

sub _str_cmp {
    my ($self, $str, $swap) = @_;
    return $str cmp $self->name if $swap;
    return $self->name cmp $str;
}

sub _str_concat {
    my ($self, $str, $swap) = @_;
    return $str . $self->name if $swap;
    return $self->name . $str;
}

sub _str_eq {
    my ($self, $str) = @_;
    return $self->name eq $str;
}

sub _str_ne {
    my ($self, $str) = @_;
    return $self->name ne $str;
}

=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et


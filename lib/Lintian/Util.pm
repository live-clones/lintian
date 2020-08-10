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
use autodie;

use Exporter qw(import);

# Force export as soon as possible, since some of the modules we load also
# depend on us and the sequencing can cause things not to be exported
# otherwise.
our @EXPORT_OK;

BEGIN {
    eval { require PerlIO::gzip };
    if ($@) {
        *open_gz = \&__open_gz_ext;
    } else {
        *open_gz = \&__open_gz_pio;
    }

    @EXPORT_OK = (qw(
          get_file_checksum
          get_file_digest
          do_fork
          run_cmd
          copy_dir
          human_bytes
          open_gz
          perm2oct
          locate_executable
          normalize_pkg_path
          normalize_link_target
          is_ancestor_of
          locate_helper_tool
          drain_pipe
          drop_relative_prefix
          read_md5sums
          version_from_changelog
          $PKGNAME_REGEX
          $PKGREPACK_REGEX
          $PKGVERSION_REGEX
    ));
}

use Carp qw(croak);
use Cwd qw(abs_path);
use Digest::MD5;
use Digest::SHA;
use Encode ();
use Errno qw(ENOENT);
use FileHandle;
use List::MoreUtils qw(first_value);
use Path::Tiny;
use POSIX qw(sigprocmask SIG_BLOCK SIG_UNBLOCK SIG_SETMASK);
use Scalar::Util qw(openhandle);
use Unicode::UTF8 qw(valid_utf8);

use Lintian::Deb822::File;
use Lintian::Inspect::Changelog;
use Lintian::Relation::Version qw(versions_equal versions_comparator);

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant SLASH => q{/};
use constant DOT => q{.};
use constant DOUBLEDOT => q{..};
use constant BACKSLASH => q{\\};
use constant NEWLINE => qq{\n};

# preload cache for common permission strings
# call overhead o perm2oct was measurable on chromium-browser/32.0.1700.123-2
# load time went from ~1.5s to ~0.1s; of 115363 paths, only 306 were uncached
my %OCTAL_LOOKUP = map { $_ => perm2oct($_) } (
    '-rw-r--r--', # standard (non-executable) file
    '-rwxr-xr-x', # standard executable file
    'drwxr-xr-x', # standard dir perm
    'drwxr-sr-x', # standard dir perm with suid (lintian-lab on lintian.d.o)
    'lrwxrwxrwx', # symlinks
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

our $PKGVERSION_REGEX = qr/
                 (?: \d+ : )?                # Optional epoch
                 [0-9][0-9A-Za-z.+:~]*       # Upstream version (with no hyphens)
                 (?: - [0-9A-Za-z.+:~]+ )*   # Optional debian revision (+ upstreams versions with hyphens)
                          /xa;

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

    1 while (read($fd, $buffer, 4096) > 0);

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
    open(my $fd, '<', $file);
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
    my $digest = get_file_digest(@_);
    return $digest->hexdigest;
}

=item do_fork()

Overrides fork to reset signal handlers etc. in the child.

=cut

sub do_fork() {
    my ($pid, $fork_error);
    my $orig_mask = POSIX::SigSet->new;
    my $fork_mask = POSIX::SigSet->new;
    $fork_mask->fillset;
    sigprocmask(SIG_BLOCK, $fork_mask, $orig_mask)
      or die("sigprocmask failed: $!\n");
    $pid = CORE::fork();
    $fork_error = $!;
    if (defined($pid) and $pid == 0) {

        for my $sig (keys(%SIG)) {
            if (ref($SIG{$sig}) eq 'CODE') {
                $SIG{$sig} = 'DEFAULT';
            }
        }
    }
    if (!sigprocmask(SIG_SETMASK, $orig_mask, undef)) {
        # The child MUST NOT use die as the caller cannot distinguish
        # the caller from the child via an exception.
        my $sigproc_error = $!;
        if (not defined($pid) or $pid != 0) {
            die("sigprocmask failed (do_fork, parent): $sigproc_error\n");
        }
        print STDERR "sigprocmask failed (do_fork, child): $sigproc_error\n";
        POSIX::_exit(255);
    }
    if (not defined($pid)) {
        $! = $fork_error;
    }
    return $pid;
}

=item perm2oct(PERM)

Translates PERM to an octal permission.  PERM should be a string describing
the permissions as done by I<tar t> or I<ls -l>.  That is, it should be a
string like "-rw-r--r--".

If the string does not appear to be a valid permission, it will cause
a trappable error.

Examples:

 # Good
 perm2oct('-rw-r--r--') == 0644
 perm2oct('-rwxr-xr-x') == 0755

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
        $text !~ m/^   [-bcdhlp]                # file type
                    ([-r])([-w])([-xsS])     # user
                    ([-r])([-w])([-xsS])     # group
                    ([-r])([-w])([-xtT])     # other
               /xsm
    ) {
        croak "$text does not appear to be a permission string";
    }

    $octal += 00400 if $1 eq 'r';   # owner read
    $octal += 00200 if $2 eq 'w';   # owner write
    $octal += 00100 if $3 eq 'x';   # owner execute
    $octal += 04000 if $3 eq 'S';   # setuid
    $octal += 04100 if $3 eq 's';   # setuid + owner execute
    $octal += 00040 if $4 eq 'r';   # group read
    $octal += 00020 if $5 eq 'w';   # group write
    $octal += 00010 if $6 eq 'x';   # group execute
    $octal += 02000 if $6 eq 'S';   # setgid
    $octal += 02010 if $6 eq 's';   # setgid + group execute
    $octal += 00004 if $7 eq 'r';   # other read
    $octal += 00002 if $8 eq 'w';   # other write
    $octal += 00001 if $9 eq 'x';   # other execute
    $octal += 01000 if $9 eq 'T';   # stickybit
    $octal += 01001 if $9 eq 't';   # stickybit + other execute

    $OCTAL_LOOKUP{$text} = $octal;

    return $octal;
}

=item run_cmd([OPTS, ]COMMAND[, ARGS...])

Executes the given C<COMMAND> with the (optional) arguments C<ARGS> and
returns the status code as one would see it from a shell script.  Shell
features cannot be used.

OPTS, if given, is a hash reference with zero or more of the following key-value pairs:

=over 4

=item chdir

The child process with chdir to the given directory before executing the command.

=item in

The STDIN of the child process will be reopened and read from the filename denoted by the value of this key.
By default, STDIN will reopened to read from /dev/null.

=item out

The STDOUT of the child process will be reopened and write to filename denoted by the value of this key.
By default, STDOUT is discarded.

=item update-env-vars

Each key/value pair defined in the hashref associated with B<update-env-vars> will be updated in the
child processes's environment.  If a value is C<undef>, then the corresponding environment variable
will be removed (if set).  Otherwise, the environment value will be set to that value.

=back

=cut

sub run_cmd {
    my (@cmd_args) = @_;
    my ($opts, $pid);
    if (ref($cmd_args[0]) eq 'HASH') {
        $opts = shift(@cmd_args);
    } else {
        $opts = {};
    }
    $pid = do_fork();
    if (not defined($pid)) {
        # failed
        die("fork failed: $!\n");
    } elsif ($pid > 0) {
        # parent
        waitpid($pid, 0);
        if ($?) {
            my $exit_code = ($? >> 8) & 0xff;
            my $signal = $? & 0x7f;
            my $cmd = join(' ', @cmd_args);
            if ($exit_code) {
                die("Command $cmd returned: $exit_code\n");
            } else {
                my $signame = signal_number2name($signal);
                die("Command $cmd received signal: $signame ($signal)\n");
            }
        }
    } else {
        # child
        if (defined(my $env = $opts->{'update-env-vars'})) {
            while (my ($k, $v) = each(%{$env})) {
                if (defined($v)) {
                    $ENV{$k} = $v;
                } else {
                    delete($ENV{$k});
                }
            }
        }
        if ($opts->{'in'}) {
            open(STDIN, '<', $opts->{'in'});
        } else {
            open(STDIN, '<', '/dev/null');
        }
        if ($opts->{'out'}) {
            open(STDOUT, '>', $opts->{'out'});
        } else {
            open(STDOUT, '>', '/dev/null');
        }
        chdir($opts->{'chdir'}) if $opts->{'chdir'};
        # Avoid shell evaluation.
        CORE::exec {$cmd_args[0]} @cmd_args
          or die("Failed to exec '$_[0]': $!\n");
    }
    return 1;
}

=item copy_dir (ARGS)

Convenient way of calling I<cp -a ARGS>.

=cut

sub copy_dir {
    # --reflink=auto (coreutils >= 7.5).  On FS that support it,
    # make a CoW copy of the data; otherwise fallback to a regular
    # deep copy.
    return run_cmd('cp', '-a', '--reflink=auto', '--', @_);
}

=item human_bytes(SIZE)

=cut

sub human_bytes {
    my ($size) = @_;

    my @units = ('B', 'kiB', 'MiB', 'GiB');

    my $unit = shift @units;

    while ($size > 1536 && @units) {

        $size /= 1024;
        $unit = shift @units;
    }

    my $human = sprintf('%.0f %s', $size, $unit);

    return $human;
}

=item open_gz (FILE)

Opens a handle that reads from the GZip compressed FILE.

On failure, this sub emits a trappable error.

Note: The handle may be a pipe from an external processes.

=cut

# Preferred implementation of open_gz (used if the perlio layer
# is available)
sub __open_gz_pio {
    my ($file) = @_;
    open(my $fd, '<:gzip', $file);
    return $fd;
}

# Starting on 7/27/20, lintian depends on libperlio-gzip-perl
# Fallback implementation of open_gz
sub __open_gz_ext {
    my ($file) = @_;
    open(my $fd, '-|', 'gzip', '-dc', $file);
    return $fd;
}

=item locate_helper_tool(TOOLNAME)

Given the name of a helper tool, returns the path to it.  The tool
must be available in the "helpers" subdir of one of the "lintian root"
directories used by Lintian.

The tool name should follow the same rules as check names.
Particularly, third-party checks should namespace their tools in the
same way they namespace their checks.  E.g. "python/some-helper".

If the tool cannot be found, this sub will cause a trappable error.

=cut

{
    my %_CACHE;

    sub locate_helper_tool {
        my ($toolname) = @_;
        if ($toolname =~ m{(?:\A|/) \.\. (?:\Z|/)}xsm) {
            croak "$toolname is not a valid tool name";
        }
        return $_CACHE{$toolname} if exists $_CACHE{$toolname};

        my $toolpath_str = $ENV{'LINTIAN_HELPER_DIRS'};
        if (defined($toolpath_str)) {
            # NB: We rely on LINTIAN_HELPER_DIRS to contain only
            # absolute paths.  Otherwise we may return relative
            # paths.
            for my $dir (split(':', $toolpath_str)) {
                my $tool = "$dir/$toolname";
                next unless -f -x $tool;
                $_CACHE{$toolname} = $tool;
                return $tool;
            }
        }
        $toolpath_str //= '<N/A>';

        croak "Cannot locate $toolname (search dirs: $toolpath_str)";
    }
}

=item locate_executable (CMD)

=cut

sub locate_executable {
    my ($command) = @_;

    return EMPTY
      unless exists $ENV{PATH};

    my @folders =  grep { length } split(/:/, $ENV{PATH});
    my $path = first_value { -x "$_/$command" } @folders;

    return ($path // EMPTY);
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

    return EMPTY
      unless -f $changelog_path;

    my $contents = path($changelog_path)->slurp_utf8;
    my $changelog = Lintian::Inspect::Changelog->new;

    $changelog->parse($contents);
    my @entries = @{$changelog->entries};

    return $entries[0]->{'Version'}
      if @entries;

    return EMPTY;
}

=item signal_number2name(NUM)

Given a number, returns the name of the signal (without leading
"SIG").  Example:

    signal_number2name(2) eq 'INT'

=cut

{
    my @signame;

    sub signal_number2name {
        my ($number) = @_;
        if (not @signame) {
            require Config;
            # Doubt this happens for Lintian, but the code might
            # Cargo-cult-copied or copy-wasted into another project.
            # Speaking of which, thanks to
            #  http://www.ccsf.edu/Pub/Perl/perlipc/Signals.html
            defined($Config::Config{sig_name})
              or die "Signals not available\n";
            my $i = 0;
            for my $name (split(' ', $Config::Config{sig_name})) {
                $signame[$i] = $name;
                $i++;
            }
        }
        return $signame[$number];
    }
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
safe to open a given symlink.  Use
L<is_ancestor_of|Lintian::Util/is_ancestor_of(PARENTDIR, PATH)> for
that.  If you must use this function, remember to check that the
target is not a symlink (or if it is, that it can be resolved safely).

=cut

sub normalize_link_target {
    my ($path, $target) = @_;

    if (substr($target, 0, 1) eq SLASH) {
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

    return EMPTY
      if $path eq SLASH;

    my @dirty = split(m{/}, $path);
    my @clean = grep { length } @dirty;

    my @final;
    for my $component (@clean) {

        if ($component eq DOT) {
            # do nothing

        } elsif ($component eq DOUBLEDOT) {
            # are we out of bounds?
            my $discard = pop @final;
            return
              unless defined $discard;

        } else {
            push(@final, $component);
        }
    }

    # empty if we end in the root
    my $normalized = join(SLASH, @final);

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
    my $resolved_file = abs_path($file)// croak("resolving $file failed: $!");
    my $resolved_ancestor = abs_path($ancestor)
      // croak("resolving $ancestor failed: $!");
    my $len;
    return 1 if $resolved_ancestor eq $resolved_file;
    # add a slash, "path/some-dir" is not "path/some-dir-2" and this
    # allows us to blindly match against the root dir.
    $resolved_file .= '/';
    $resolved_ancestor .= '/';

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
        if ($char eq BACKSLASH && !$escaped) {
            $escaped = 1;
            next;
        }

        # unescape newline
        $char = NEWLINE
          if $char eq 'n' && $escaped;

        # append character
        $path .= $char;

        # end any escape sequence
        $escaped = 0;
    }

    # do not stop inside an escape sequence
    die 'Name terminated inside an escape sequence'
      if $escaped;

    return $path;
}

sub read_md5sums {
    my ($text) = @_;

    my %checksums;
    my @errors;

    my @lines = split(/\n/, $text);

    # start with checksum; processing style inspired by IO::Async::Stream
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

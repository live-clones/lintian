# binaries -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2012 Kees Cook
# Copyright © 2017-2020 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Binaries;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Spec;
use List::SomeUtils qw(any);
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Relation;
use Lintian::Spelling qw(check_spelling);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $NUMPY_REGEX => qr{
    \Qmodule compiled against ABI version \E (?:0x)?%x
    \Q but this version of numpy is \E (?:0x)?%x
}x;

# Guile object files do not objdump/strip correctly, so exclude them
# from a number of tests. (#918444)
const my $GUILE_PATH_REGEX => qr{^usr/lib(?:/[^/]+)+/guile/[^/]+/.+\.go$};

# These are the ones file(1) looks for.  The ".zdebug_info" being the
# compressed version of .debug_info.
# - Technically, file(1) also looks for .symtab, but that is apparently
#   not strippable for static libs.  Accordingly, it is omitted below.
const my @DEBUG_SECTIONS => qw(.debug_info .zdebug_info);

const my $EMPTY => q{};

my %PATH_DIRECTORIES = map { $_ => 1 } qw(
  bin/ sbin/ usr/bin/ usr/sbin/ usr/games/ );

sub spelling_tag_emitter {
    my ($self, @orig_args) = @_;
    return sub {
        return $self->hint(@orig_args, @_);
    };
}

sub _embedded_libs {
    my ($key, $some_val, undef) = @_;
    my $result = {'libname' => $key,};
    my ($opts, $regex) = split m/\|\|/, $some_val, 2;
    if (!$regex) {
        $regex = $opts;
        $opts = $EMPTY;
    } else {

        # trim both ends
        $opts =~ s/^\s+|\s+$//g;

        foreach my $optstr (split m/\s++/, $opts) {
            my ($opt, $val) = split m/=/, $optstr, 2;
            if ($opt eq 'source' or $opt eq 'libname') {
                $result->{$opt} = $val;
            } elsif ($opt eq 'source-regex') {
                $result->{$opt} = qr/$val/;
            } else {
                die encode_utf8(
                    "Unknown option $opt for $key (in binaries/embedded-libs)"
                );
            }
        }
    }

    if (defined $result->{'source'} and $result->{'source-regex'}) {
        die encode_utf8(
"Both source and source-regex used for $key (in binaries/embedded-libs)"
        );
    } else {
        $result->{'source'} = $key unless defined $result->{'source'};
    }

    $result->{'match'} = qr/$regex/;

    return $result;
}

sub lib_soname_path {
    my ($dir, @paths) = @_;

    for my $path (@paths) {
        next
          if $path=~ m{^(?:usr/)?lib(?:32|64)?/libnss_[^.]+\.so(?:\.\d+)$};

        return 1
          if $path =~ m{^lib/[^/]+$};
        return 1
          if $path =~ m{^usr/lib/[^/]+$};
        return 1
          if defined $dir && $path =~ m{^lib/$dir/[^/]+$};
        return 1
          if defined $dir && $path =~ m{^usr/lib/$dir/[^/]+$};
    }
    return 0;
}

our $ARCH_32_REGEX;

sub installable {
    my ($self) = @_;

    my $pkg = $self->processable->name;
    my $type = $self->processable->type;
    my $processable = $self->processable;
    my $group = $self->group;

    my $ARCH_REGEX
      = $self->profile->load_data('binaries/arch-regex', qr/\s*\~\~/,
        sub { return qr/$_[1]/ });

    my $HARDENED_FUNCTIONS
      = $self->profile->load_data('binaries/hardened-functions');

    my $LFS_SYMBOLS = $self->profile->load_data('binaries/lfs-symbols');

    my $OBSOLETE_CRYPT_FUNCTIONS
      = $self->profile->load_data('binaries/obsolete-crypt-functions',
        qr/\s*\|\|\s*/);

    my ($madir, %directories, $built_with_golang, $built_with_octave, %SONAME);
    my ($gnu_triplet_re, $ruby_triplet_re);
    my $needs_libc = $EMPTY;
    my $needs_libcxx = $EMPTY;
    my $needs_libc_file;
    my $needs_libcxx_file;
    my $needs_libc_count = 0;
    my $needs_libcxx_count = 0;
    my %needs_depends;
    my $has_perl_lib = 0;
    my $has_php_ext = 0;
    my $uses_numpy_c_abi = 0;

    my $arch = $processable->fields->value('Architecture');
    my $multiarch = $processable->fields->value('Multi-Arch') || 'no';
    my $srcpkg = $processable->source_name;

    my $hardening_buildflags = $self->profile->hardening_buildflags;
    my %recommended_hardening_features;
    %recommended_hardening_features
      = map { $_ => 1 } @{$hardening_buildflags->recommended_features->{$arch}}
      if $arch ne 'all';

    my $src = $group->source;
    if (defined($src)) {
        $built_with_golang = $src->relation('Build-Depends-All')
          ->implies('golang-go | golang-any');
        $built_with_octave
          = $src->relation('Build-Depends')->implies('dh-octave');
    } else {
        $built_with_golang = $pkg =~ m/^golang-/;
        $built_with_octave = $pkg =~ m/^octave-/;
    }

    foreach my $name (sort keys %{$processable->objdump_info}) {
        my $objdump = $processable->objdump_info->{$name};
        my ($has_lfs, %unharded_functions, @hardened_functions);
        my $is_profiled = 0;

        # $name can be an object inside a static lib.  These do
        # not appear in the output of our file_info collection.
        my $file = $processable->installed->lookup($name);
        my $file_info = $EMPTY;
        $file_info = $file->file_info
          if defined $file;

        # The LFS check only works reliably for ELF files due to the
        # architecture regex.
        if ($file_info =~ /^[^,]*\bELF\b/) {
            # Only 32bit ELF binaries can lack LFS.
            $ARCH_32_REGEX = $ARCH_REGEX->value('32')
              unless defined $ARCH_32_REGEX;
            $has_lfs = 1 unless $file_info =~ m/$ARCH_32_REGEX/;
            # We don't care if it is a debug file
            $has_lfs = 1 if $name =~ m{^usr/lib/debug/};
        }

        if (defined $objdump->{SONAME}) {
            foreach my $soname (@{$objdump->{SONAME}}) {
                $SONAME{$soname} ||= [];
                push @{$SONAME{$soname}}, $name;
            }
        }
        foreach my $symbol (@{$objdump->{SYMBOLS}}) {
            my ($foo, $sec, $sym) = @{$symbol};

            if ($foo eq 'UND') {
                my $name = $sym;
                my $hardened;
                $hardened = 1 if $name =~ s/^__(\S+)_chk$/$1/;
                if ($HARDENED_FUNCTIONS->recognizes($name)) {
                    if ($hardened) {
                        push(@hardened_functions, $name);
                    } else {
                        $unharded_functions{$name} = 1;
                    }
                }

            }

            unless (defined $has_lfs) {
                if ($foo eq 'UND' and $LFS_SYMBOLS->recognizes($sym)) {
                    # Using a 32bit only interface call, some parts of the
                    # binary are built without LFS. If the symbol is defined
                    # within the binary then we ignore it
                    $has_lfs = 0;
                }
            }

            if ($foo eq 'UND' and $OBSOLETE_CRYPT_FUNCTIONS->recognizes($sym)){
                # Using an obsolete DES encryption function.
                my $tag = $OBSOLETE_CRYPT_FUNCTIONS->value($sym);
                $self->hint($tag, $name, $sym);
            }

            next if $is_profiled;
            # According to the binutils documentation[1], the profiling symbol
            # can be named "mcount", "_mcount" or even "__mcount".
            # [1] http://sourceware.org/binutils/docs/gprof/Implementation.html
            if (    $sec =~ /^GLIBC_.*/
                and $sym =~ m{\A _?+ _?+ (gnu_)?+mcount(_nc)?+ \Z}xsm) {
                $is_profiled = 1;
            } elsif ($arch ne 'hppa') {
                # This code was used to detect profiled code in Wheezy
                # (and earlier)
                if (    $foo eq '.text'
                    and $sec eq 'Base'
                    and$sym eq '__gmon_start__') {
                    $is_profiled = 1;
                }
            }
            $self->hint('binary-compiled-with-profiling-enabled', $name)
              if $is_profiled;
        }
        if (    %unharded_functions
            and not @hardened_functions
            and not $built_with_golang
            and $recommended_hardening_features{fortify}) {
            $self->hint('hardening-no-fortify-functions', $name);
        }

        $self->hint('apparently-corrupted-elf-binary', $name)
          if $objdump->{'ERRORS'};
        $self->hint('binary-file-built-without-LFS-support', $name)
          if defined $has_lfs and not $has_lfs;
        if ($objdump->{'BAD-DYNAMIC-TABLE'}) {
            $self->hint('binary-with-bad-dynamic-table', $name)
              unless $name =~ m{^usr/lib/debug/};
        }
    }

    my $ARCH_64BIT_EQUIVS
      = $self->profile->load_data('binaries/arch-64bit-equivs',qr/\s*\=\>\s*/);

    my $BINARY_SPELLING_EXCEPTIONS
      = $self->profile->load_data('binaries/spelling-exceptions', qr/\s+/);

    my $EMBEDDED_LIBRARIES
      = $self->profile->load_data('binaries/embedded-libs', qr/\s*+\|\|/,
        \&_embedded_libs);

    # For the package naming check, filter out SONAMEs where all the
    # files are at paths other than /lib, /usr/lib and /usr/lib/<MA-DIR>.
    # This avoids false positives with plugins like Apache modules,
    # which may have their own SONAMEs but which don't matter for the
    # purposes of this check.  Also filter out nsswitch modules
    my $DEB_HOST_MULTIARCH= $self->profile->architectures->deb_host_multiarch;
    $madir = $DEB_HOST_MULTIARCH->{$arch};
    if (not defined($madir)) {
        # In the case that the architecture is "all" or unknown (or we do
        # not know the multi-arch path for a known architecture) , we assume
        # it the multi-arch path to be this (hopefully!) non-existent path to
        # avoid warnings about uninitialized variables.
        $madir = './!non-existent-path!/./';
    }

    $gnu_triplet_re = quotemeta $madir;
    $gnu_triplet_re =~ s{^i386}{i[3-6]86};
    $ruby_triplet_re = $gnu_triplet_re;
    $ruby_triplet_re =~ s{linux\\-gnu$}{linux};
    $ruby_triplet_re =~ s{linux\\-gnu}{linux\\-};

    my @sonames
      = sort grep { lib_soname_path($madir, @{$SONAME{$_}}) } keys %SONAME;

    # try to identify transition strings
    my $base_pkg = $pkg;
    $base_pkg =~ s/c102\b//;
    $base_pkg =~ s/c2a?\b//;
    $base_pkg =~ s/\dg$//;
    $base_pkg =~ s/gf$//;
    $base_pkg =~ s/v[5-6]$//; # GCC-5 / libstdc++6 C11 ABI breakage
    $base_pkg =~ s/-udeb$//;
    $base_pkg =~ s/^lib64/lib/;

    my $match_found = 0;
    foreach my $expected_name (@sonames) {
        $expected_name =~ s/([0-9])\.so\./$1-/;
        $expected_name =~ s/\.so(?:\.|\z)//;
        $expected_name =~ s/_/-/g;

        if (   (lc($expected_name) eq $pkg)
            || (lc($expected_name) eq $base_pkg)) {
            $match_found = 1;
            last;
        }
    }

    $self->hint('package-name-doesnt-match-sonames', "@sonames")
      if @sonames && !$match_found && $type ne 'udeb';

    # process all files in package
    for my $file (@{$processable->installed->sorted_list}) {
        my ($fileinfo, $objdump, $fname);

        next
          unless $file->is_file;

        $fileinfo = $file->file_info;

        # binary or object file?
        next
          unless ($fileinfo =~ m/^[^,]*\bELF\b/)
          or ($fileinfo =~ m/\bcurrent ar archive\b/);

        # Warn about Architecture: all packages that contain shared libraries.
        if ($arch eq 'all') {
            $self->hint('arch-independent-package-contains-binary-or-object',
                $file);
        }

        $fname = $file->name;
        if ($fname =~ m{^etc/}) {
            $self->hint('binary-in-etc', $file);
        }

        if ($fname =~ m{^usr/share/}) {
            $self->hint('arch-dependent-file-in-usr-share', $file);
        }

        if ($multiarch eq 'same') {
            unless ($fname
                =~ m{\b$gnu_triplet_re(?:\b|_)|/(?:$ruby_triplet_re|java-\d+-openjdk-\Q$arch\E|\.build-id)/}
            ) {
                $self->hint(
                    'arch-dependent-file-not-in-arch-specific-directory',
                    $file);
            }
        }
        if ($fileinfo =~ m/\bcurrent ar archive\b/) {

            # "libfoo_g.a" is usually a "debug" library, so ignore
            # unneeded sections in those.
            next if $file =~ m/_g\.a$/;

            $objdump = $processable->objdump_info->{$file};

            foreach my $obj (@{ $objdump->{'objects'} }) {
                my $libobj = $processable->objdump_info->{"${file}(${obj})"};
                # Shouldn't happen, but...
                die encode_utf8(
                    "object ($file $obj) in static lib is missing!?")
                  unless defined $libobj;

                if (any { exists($libobj->{'SH'}{$_}) } @DEBUG_SECTIONS) {
                    $self->hint('unstripped-static-library',"${file}(${obj})");
                } else {
                    $self->tag_unneeded_sections(
                        'static-library-has-unneeded-section',
                        "${file}(${obj})", $libobj);
                }
            }
        }

        # ELF?
        next unless $fileinfo =~ /^[^,]*\bELF\b/;

        $self->hint('development-package-ships-elf-binary-in-path', $file)
          if exists($PATH_DIRECTORIES{$file->dirname})
          and ($processable->fields->value('Section') || 'NONE')
          =~ m/(?:^|\/)libdevel$/
          and ($processable->fields->value('Multi-Arch') || 'NONE') ne
          'foreign';

        $objdump = $processable->objdump_info->{$fname};

        if ($arch eq 'all' or not $ARCH_REGEX->recognizes($arch)) {
            # arch:all or unknown architecture - not much we can say here
            1;
        } else {
            my $archre = $ARCH_REGEX->value($arch);
            my $bad = 1;
            if ($fileinfo =~ m/$archre/) {
                # If it matches the architecture regex, it is good
                $bad = 0;
            } elsif ($fname =~ m{(?:^|/)lib(x?\d\d)/}
                or $fname =~ m{^emul/ia(\d\d)}) {
                my $bitre = $ARCH_REGEX->value($1);
                # Special case - "old" multi-arch dirs
                $bad = 0 if $bitre and $fileinfo =~ m/$bitre/;
            } elsif ($fname =~ m{^usr/lib/debug/\.build-id/}) {
                # Detached debug symbols could be for a biarch library.
                $bad = 0;
            } elsif ($fname =~ $GUILE_PATH_REGEX) {
                # Guile binaries do not objdump/strip (etc.) correctly.
                $bad = 0;
            } elsif ($ARCH_64BIT_EQUIVS->recognizes($arch)
                && $fname =~ m{^lib/modules/}) {
                my $arch64re
                  = $ARCH_REGEX->value($ARCH_64BIT_EQUIVS->value($arch));
                # Allow amd64 kernel modules to be installed on i386.
                $bad = 0 if $fileinfo =~ m/$arch64re/;
            } elsif ($arch eq 'amd64') {
                my $arch32re = $ARCH_REGEX->value('i386');
                # Ignore i386 binaries in amd64 packages for right now.
                $bad = 0 if $fileinfo =~ m/$arch32re/;
            }
            $self->hint('binary-from-other-architecture', $file) if $bad;
        }

        my $exceptions = {
            %{ $group->spelling_exceptions },
            map { $_ => 1} $BINARY_SPELLING_EXCEPTIONS->all
        };
        my $tag_emitter
          = $self->spelling_tag_emitter('spelling-error-in-binary', $file);
        check_spelling($self->profile, $file->strings, $exceptions,
            $tag_emitter, 0);

        # stripped?
        if ($fileinfo =~ m{\bnot stripped\b}) {
            # Is it an object file (which generally cannot be
            # stripped), a kernel module, debugging symbols, or
            # perhaps a debugging package?
            unless ($fname =~ /\.k?o$/
                || $pkg =~ /-dbg$/
                || $pkg =~ /debug/
                || $fname =~ m{/lib/debug/}
                || $fname =~ $GUILE_PATH_REGEX
                || $fname =~ /\.gox$/) {

                if (    $fileinfo =~ m/executable/
                    and $file->strings =~ m/^Caml1999X0[0-9][0-9]$/m) {
                    # Check for OCaml custom executables (#498138)
                    $self->hint('ocaml-custom-executable', $file);
                } else {
                    $self->hint('unstripped-binary-or-object', $file);
                }
            }
        } else {
            # stripped but a debug or profiling library?
            if ($fname =~ m{/lib/debug/} || $fname =~ m{/lib/profile/}) {
                $self->hint('stripped-library',$file)
                  unless $file->size == 0;
            } else {
                # appropriately stripped, but is it stripped enough?
                $self->tag_unneeded_sections('binary-has-unneeded-section',
                    $file,$objdump);
            }
        }

        # rpath is disallowed, except in private directories
        if (exists($objdump->{RPATH}) or exists($objdump->{RUNPATH})) {
            if (not %directories) {
                for my $file (@{$processable->installed->sorted_list}) {
                    my $name;
                    next unless $file->is_dir || $file->is_symlink;
                    $name = $file->name;
                    $name =~ s{/\z}{};
                    $directories{"/$name"}++;
                }
            }
            my @rpaths
              = (keys(%{$objdump->{RPATH}}),keys(%{$objdump->{RUNPATH}}),);

            foreach my $rpath (map {File::Spec->canonpath($_)}@rpaths) {
                next
                  if $rpath
                  =~ m{^/usr/lib/(?:$madir/)?(?:games/)?(?:\Q$pkg\E|\Q$srcpkg\E)(?:/|\z)};
                next if $rpath =~ m{^\$\{?ORIGIN\}?};
                # GHC in Debian uses a scheme for RPATH. (#914873)
                next if $rpath =~ m{^/usr/lib/ghc/};
                next
                  if $directories{$rpath}
                  && $rpath !~ m{^(?:/usr)?/lib(?:/$madir)?/?\z};
                $self->hint('custom-library-search-path', $file, $rpath);
            }
        }

        foreach my $emlib ($EMBEDDED_LIBRARIES->all) {
            my $ldata = $EMBEDDED_LIBRARIES->value($emlib);
            if ($ldata->{'source-regex'}) {
                next
                  if $processable->source_name=~ m/^$ldata->{'source-regex'}$/;
            } else {
                next if $processable->source_name eq $ldata->{'source'};
            }
            if ($file->strings =~ $ldata->{'match'}) {
                $self->hint('embedded-library', "$fname: $ldata->{'libname'}");
            }
        }

        # binary or shared object?
        next
          unless ($fileinfo =~ m/executable/)
          or ($fileinfo =~ m/shared object/);

        next
          if $type eq 'udeb';

        # Perl library?
        $has_perl_lib = 1
          if $fname =~ m{^usr/lib/(?:[^/]+/)?perl5/.*\.so$};

        # PHP extension?
        $has_php_ext = 1
          if $fname =~ m{^usr/lib/php\d/.*\.so(?:\.\d+)*$};

        # Python extension using Numpy C ABI?
        if (
            $fname =~ m{^usr/lib/(?:pyshared/)?python2\.\d+/.*(?<!_d)\.so$}
            || (   $fname =~ m{^usr/lib/python3/.+\.cpython-\d+([a-z]+)\.so$}
                && $1 !~ /d/)
        ) {
            $uses_numpy_c_abi = 1
              if $file->strings =~ / numpy /msx
              && $file->strings =~ $NUMPY_REGEX;
        }

        # Something other than detached debugging symbols in
        # /usr/lib/debug paths.
        if ($fname
            =~ m{^usr/lib/debug/(?:lib\d*|s?bin|usr|opt|dev|emul|\.build-id)/})
        {
            if (exists($objdump->{NEEDED})) {
                $self->hint('debug-symbols-not-detached', $file);
            }
            $self->hint('debug-file-with-no-debug-symbols', $file)
              unless (exists $objdump->{'SH'}{'.debug_line'}
                or exists $objdump->{'SH'}{'.zdebug_line'}
                or exists $objdump->{'SH'}{'.debug_str'}
                or exists $objdump->{'SH'}{'.zdebug_str'});
        }

        # Detached debugging symbols directly in /usr/lib/debug.
        if ($fname =~ m{^usr/lib/debug/[^/]+$}) {
            unless (exists($objdump->{NEEDED})
                || $fileinfo =~ m/statically linked/) {
                $self->hint('debug-symbols-directly-in-usr-lib-debug', $file);
            }
        }

        # statically linked?
        if (!exists($objdump->{NEEDED})) {
            if ($fileinfo =~ /(shared object|pie executable)/) {
                # Some exceptions: kernel modules, syslinux modules, detached
                # debugging information and the dynamic loader (which itself
                # has no dependencies).
                next if $fname =~ m{^boot/modules/};
                next if $fname =~ m{^lib/modules/};
                next if $fname =~ m{^usr/lib/debug/};
                next if $fname =~ m{\.(?:[ce]32|e64)$};
                next if $fname =~ m{^usr/lib/jvm/.*\.debuginfo$};
                next if $fname =~ $GUILE_PATH_REGEX;
                next
                  if (
                    $fname =~ m{
                                  ^lib(?:|32|x32|64)/
                                   (?:[-\w/]+/)?
                                   ld-[\d.]+\.so$
                                }xsm
                  );
                $self->hint('shared-library-lacks-prerequisites', $file);
            } else {
                # Some exceptions: files in /boot, /usr/lib/debug/*,
                # named *-static or *.static, or *-static as
                # package-name.
                next if $fname =~ m{^boot/};
                next if $fname =~ /[\.-]static$/;
                next if $pkg =~ /-static$/;
                # Binaries built by the Go compiler are statically
                # linked by default.
                next if $built_with_golang;
                # klibc binaries appear to be static.
                next
                  if exists $objdump->{INTERP}
                  && $objdump->{INTERP} =~ m{/lib/klibc-\S+\.so};
                # Location of debugging symbols.
                next if $fname =~ m{^usr/lib/debug/};
                # ldconfig must be static.
                next if $fname eq 'sbin/ldconfig';
                $self->hint('statically-linked-binary', $file);
            }
        } else {
            my $no_libc = 1;
            my $is_shared = 0;
            my @needed;
            $needs_depends{$file->name} = 1;
            $is_shared = 1 if $fileinfo =~ m/(shared object|pie executable)/;
            @needed = @{$objdump->{NEEDED}} if exists($objdump->{NEEDED});
            for my $lib (@needed) {
                if ($lib =~ /^libc\.so\.(\d+.*)/) {
                    $needs_libc = "libc$1";
                    $needs_libc_file = $fname unless $needs_libc_file;
                    $needs_libc_count++;
                    $no_libc = 0;
                }
                if ($lib =~ m{\A libstdc\+\+\.so\.(\d+) \Z}xsm) {
                    $needs_libcxx = "libstdc++$1";
                    $needs_libcxx_file = $fname
                      unless $needs_libcxx_file;
                    $needs_libcxx_count++;
                }
            }
            if (   $no_libc
                && $fname !~ m{/libc\b}
                && (!$built_with_octave || $fname !~ m/\.(?:oct|mex)$/)) {
                # If there is no libc dependency, then it is most likely a
                # bug.  The major exception is that some C++ libraries,
                # but these tend to link against libstdc++ instead.  (see
                # #719806)
                if ($is_shared) {
                    $self->hint('library-not-linked-against-libc', $file)
                      if $needs_libcxx eq $EMPTY;
                } else {
                    $self->hint('program-not-linked-against-libc', $file);
                }
            }

            if (    $recommended_hardening_features{relro}
                and not $built_with_golang
                and not $objdump->{'PH'}{'RELRO'}) {
                $self->hint('hardening-no-relro', $file);
            }

            if (    $recommended_hardening_features{bindnow}
                and not $built_with_golang
                and not exists($objdump->{'FLAGS_1'}{'NOW'})) {
                $self->hint('hardening-no-bindnow', $file);
            }

            if (    $recommended_hardening_features{pie}
                and not $built_with_golang
                and $objdump->{'ELF-TYPE'} eq 'EXEC') {
                $self->hint('hardening-no-pie', $file);
            }
        }
    }

    # Find the package dependencies, which is used by various checks.
    my $depends = $processable->relation('strong');

    # Check for a libc dependency.
    if ($depends->is_empty) {
        $self->hint('undeclared-elf-prerequisites', $_)for keys %needs_depends;

    } elsif (%needs_depends) {

        if ($needs_libc && $pkg !~ /^libc[\d.]+(?:-|\z)/) {
            # Match libcXX or libcXX-*, but not libc3p0.
            my $re = qr/^\Q$needs_libc\E\b/;
            if (!$depends->matches($re)) {
                my $others = $EMPTY;
                $needs_libc_count--;
                if ($needs_libc_count > 0) {
                    $others = " and $needs_libc_count others";
                }
                $self->hint('missing-dependency-on-libc',
                    "needed by $needs_libc_file$others");
            }
        }
        if ($needs_libcxx ne $EMPTY) {
            # Match libstdc++XX or libcstdc++XX-*
            my $re = qr/^\Q$needs_libcxx\E\b/;
            if (!$depends->matches($re)) {
                my $others = $EMPTY;
                $needs_libcxx_count--;
                if ($needs_libcxx_count > 0) {
                    $others = " and $needs_libcxx_count others";
                }
                $self->hint(
                    'missing-dependency-on-libstdc++',
                    "needed by $needs_libcxx_file$others"
                );
            }
        }
    }

    # Check for a Perl dependency.
    if ($has_perl_lib) {
        # It is a virtual package, so no version is allowed and
        # alternatives probably does not make sense here either.
        my $re = qr/^perlapi-[-\w.]+(?:\s*\[[^\]]+\])?$/;
        unless (
            $depends->matches($re, Lintian::Relation::VISIT_OR_CLAUSE_FULL)) {
            $self->hint('missing-dependency-on-perlapi');
        }
    }

    # Check for a phpapi- dependency.
    if ($has_php_ext) {
        # It is a virtual package, so no version is allowed and
        # alternatives probably does not make sense here either.
        unless (
            $depends->matches(
                qr/^phpapi-[\d\w+]+$/, Lintian::Relation::VISIT_OR_CLAUSE_FULL
            )
        ){
            $self->hint('missing-dependency-on-phpapi');
        }
    }

    # Check for dependency on python3-numpy-abiN dependency (or strict
    # versioned dependency on python3-numpy)
    if ($uses_numpy_c_abi and $pkg !~ m{\A python3?-numpy \Z}xsm) {
        # We do not allow alternatives as it would mostly likely
        # defeat the purpose of this relation.  Also, we do not allow
        # versions for -abi as it is a virtual package.
        my $vflags = Lintian::Relation::VISIT_OR_CLAUSE_FULL;
        $self->hint('missing-dependency-on-numpy-abi')
          unless $depends->matches(qr/^python3?-numpy-abi\d+$/, $vflags)
          or (  $depends->matches(qr/^python3-numpy \(>[>=][^\|]+$/, $vflags)
            and $depends->matches(qr/^python3-numpy \(<[<=][^\|]+$/, $vflags));
    }

    return;
}

sub tag_unneeded_sections {
    my ($self, $tag, $file, $objdump) = @_;
    foreach my $sect ('.note', '.comment') {
        if (exists $objdump->{'SH'}{$sect}) {
            $self->hint($tag, "$file $sect");
        }
    }
    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

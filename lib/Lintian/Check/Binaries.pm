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
use List::Compare;
use List::SomeUtils qw(any none);
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Relation;
use Lintian::Spelling qw(check_spelling);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SPACE => q{ };

const my $NUMPY_REGEX => qr{
    \Qmodule compiled against ABI version \E (?:0x)?%x
    \Q but this version of numpy is \E (?:0x)?%x
}x;

# Guile object files do not objdump/strip correctly, so exclude them
# from a number of tests. (#918444)
const my $GUILE_PATH_REGEX => qr{^usr/lib(?:/[^/]+)+/guile/[^/]+/.+\.go$};

const my %PATH_DIRECTORIES => map { $_ => 1 } qw(
  bin/ sbin/ usr/bin/ usr/sbin/ usr/games/ );

has DEB_HOST_MULTIARCH => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->architectures->deb_host_multiarch;
    });

has ARCH_REGEX => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('binaries/arch-regex', qr/\s*\~\~/,
            sub { return qr/$_[1]/ });
    });

has HARDENED_FUNCTIONS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('binaries/hardened-functions');
    });

has LFS_SYMBOLS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('binaries/lfs-symbols');
    });

has OBSOLETE_CRYPT_FUNCTIONS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('binaries/obsolete-crypt-functions',
            qr/\s*\|\|\s*/);
    });

has ARCH_64BIT_EQUIVS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('binaries/arch-64bit-equivs',
            qr/\s*\=\>\s*/);
    });

has BINARY_SPELLING_EXCEPTIONS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('binaries/spelling-exceptions',
            qr/\s+/);
    });

has EMBEDDED_LIBRARIES => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data(
            'binaries/embedded-libs',
            qr/\s*+\|\|/,
            sub {
                my ($label, $details) = @_;

                my ($pairs, $regex) = split(m{\|\|}, $details, 2);

                my %result;
                for my $kvpair (split($SPACE, $pairs)) {

                    my ($key, $value) = split(/=/, $kvpair, 2);
                    $result{$key} = $value;
                }

                my $lc= List::Compare->new([keys %result],
                    [qw{libname source source-regex}]);
                my @unknown = $lc->get_Lonly;

                die encode_utf8(
"Unknown options @unknown for $label (in binaries/embedded-libs)"
                )if @unknown;

                die encode_utf8(
"Both source and source-regex used for $label (in binaries/embedded-libs)"
                )if length $result{source} && length $result{'source-regex'};

                $result{match} = qr/$regex/;

                $result{libname} //= $label;
                $result{source} //= $label;

                return \%result;
            });
    });

has recommended_hardening_features => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %recommended_hardening_features;

        my $hardening_buildflags = $self->profile->hardening_buildflags;
        my $architecture = $self->processable->fields->value('Architecture');

        %recommended_hardening_features
          = map { $_ => 1 }
          @{$hardening_buildflags->recommended_features->{$architecture}}
          if $architecture ne 'all';

        return \%recommended_hardening_features;
    });

has gnu_triplet_pattern => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $gnu_triplet_pattern = $EMPTY;

        my $architecture = $self->processable->fields->value('Architecture');
        my $madir = $self->DEB_HOST_MULTIARCH->{$architecture};

        if (length $madir) {
            $gnu_triplet_pattern = quotemeta $madir;
            $gnu_triplet_pattern =~ s{^i386}{i[3-6]86};
        }

        return $gnu_triplet_pattern;
    });

has ruby_triplet_pattern => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $ruby_triplet_pattern = $self->gnu_triplet_pattern;
        $ruby_triplet_pattern =~ s{linux\\-gnu$}{linux};
        $ruby_triplet_pattern =~ s{linux\\-gnu}{linux\\-};

        return $ruby_triplet_pattern;
    });

has built_with_golang => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $built_with_golang = $self->processable->name =~ m/^golang-/;

        my $source = $self->group->source;

        $built_with_golang
          = $source->relation('Build-Depends-All')
          ->implies('golang-go | golang-any')
          if defined $source;

        return $built_with_golang;
    });

has built_with_octave => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $built_with_octave = $self->processable->name =~ m/^octave-/;

        my $source = $self->group->source;

        $built_with_octave
          = $source->relation('Build-Depends')->implies('dh-octave')
          if defined $source;

        return $built_with_octave;
    });

has needs_depends => (is => 'rw', default => sub { {} });

has needs_libc => (is => 'rw', default => $EMPTY);
has needs_libcxx => (is => 'rw', default => $EMPTY);
has needs_libc_files => (is => 'rw', default => sub { [] });
has needs_libcxx_files => (is => 'rw', default => sub { [] });

has has_perl_lib => (is => 'rw', default => 0);
has has_php_ext => (is => 'rw', default => 0);
has uses_numpy_c_abi => (is => 'rw', default => 0);

has private_directories => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my %directories;

        for my $item (@{$self->processable->installed->sorted_list}) {

            next
              unless $item->is_dir || $item->is_symlink;

            my $name = $item->name;
            $name =~ s{/\z}{};
            $directories{"/$name"}++;
        }

        return \%directories;
    });

sub spelling_tag_emitter {
    my ($self, @orig_args) = @_;

    return sub {
        return $self->hint(@orig_args, @_);
    };
}

sub lib_soname_path {
    my ($dir, @paths) = @_;

    for my $path (@paths) {
        next
          if $path=~ m{^(?:usr/)?lib(?:32|64)?/libnss_[^.]+\.so(?:\.\d+)$};

        return 1
          if $path =~ m{^ (?:usr/)? lib/ [^/]+ $}x;

        return 1
          if length $dir && $path =~ m{^ (?:usr/)? lib/ $dir/ [^/]+ $};
    }

    return 0;
}

sub installable {
    my ($self) = @_;

    my %SONAME;

    my $fields = $self->processable->fields;
    my $architecture = $fields->value('Architecture');

    for my $object_name (sort keys %{$self->processable->objdump_info}) {

        my $objdump = $self->processable->objdump_info->{$object_name};

        for my $soname (@{$objdump->{SONAME} // []}) {
            $SONAME{$soname} ||= [];
            push(@{$SONAME{$soname}}, $object_name);
        }

        my @hardened_functions;
        my @unhardened_functions;
        for my $entry (@{$objdump->{SYMBOLS}}) {
            my ($section, $version, $symbol) = @{$entry};

            next
              unless $section eq 'UND';

            if ($symbol =~ /^__(\S+)_chk$/) {
                my $vulnerable = $1;
                push(@hardened_functions, $vulnerable)
                  if $self->HARDENED_FUNCTIONS->recognizes($vulnerable);

            } else {

                push(@unhardened_functions, $symbol)
                  if $self->HARDENED_FUNCTIONS->recognizes($symbol);
            }
        }

        my $has_lfs;

        # $object_name can be an object inside a static lib.  These do
        # not appear in the output of our file_info collection.
        my $file = $self->processable->installed->lookup($object_name);

        # The LFS check only works reliably for ELF files due to the
        # architecture regex.
        if (defined $file && $file->file_info =~ /^[^,]*\bELF\b/) {

            # Only 32bit ELF binaries can lack LFS.
            $has_lfs = 1
              unless $file->file_info =~ $self->ARCH_REGEX->value('32');
        }

        for my $entry (@{$objdump->{SYMBOLS}}) {
            my ($section, $version, $symbol) = @{$entry};

            next
              unless $section eq 'UND';

            # Using a 32bit only interface call, some parts of the
            # binary are built without LFS. If the symbol is defined
            # within the binary then we ignore it
            $has_lfs //= 0
              if $self->LFS_SYMBOLS->recognizes($symbol);

            if ($self->OBSOLETE_CRYPT_FUNCTIONS->recognizes($symbol)){

                # Using an obsolete DES encryption function.
                my $tag = $self->OBSOLETE_CRYPT_FUNCTIONS->value($symbol);
                $self->hint($tag, $object_name, $symbol);
            }
        }

        for my $entry (@{$objdump->{SYMBOLS}}) {
            my ($section, $version, $symbol) = @{$entry};

            my $is_profiled = 0;

            # According to the binutils documentation[1], the profiling symbol
            # can be named "mcount", "_mcount" or even "__mcount".
            # [1] http://sourceware.org/binutils/docs/gprof/Implementation.html
            $is_profiled = 1
              if $version =~ /^GLIBC_.*/
              && $symbol =~ m{\A _?+ _?+ (gnu_)?+mcount(_nc)?+ \Z}xsm;

            # This code was used to detect profiled code in Wheezy
            # (and earlier)
            $is_profiled = 1
              if $section eq '.text'
              && $version eq 'Base'
              && $symbol eq '__gmon_start__'
              && $architecture ne 'hppa';

            $self->hint('binary-compiled-with-profiling-enabled', $object_name)
              if $is_profiled;
        }

        $self->hint('hardening-no-fortify-functions', $object_name)
          if @unhardened_functions
          && !@hardened_functions
          && !$self->built_with_golang
          && $self->recommended_hardening_features->{fortify};

        $self->hint('apparently-corrupted-elf-binary', $object_name)
          if $objdump->{ERRORS};

        $self->hint('binary-file-built-without-LFS-support', $object_name)
          if defined $has_lfs
          && !$has_lfs
          && $object_name !~ m{^usr/lib/debug/};

        $self->hint('binary-with-bad-dynamic-table', $object_name)
          if $objdump->{'BAD-DYNAMIC-TABLE'}
          && $object_name !~ m{^usr/lib/debug/};
    }

    my $madir = $self->DEB_HOST_MULTIARCH->{$architecture};

    # For the package naming check, filter out SONAMEs where all the
    # files are at paths other than /lib, /usr/lib and /usr/lib/<MA-DIR>.
    # This avoids false positives with plugins like Apache modules,
    # which may have their own SONAMEs but which don't matter for the
    # purposes of this check.  Also filter out nsswitch modules
    my @sonames
      = sort grep { lib_soname_path($madir, @{$SONAME{$_}}) } keys %SONAME;

    # try to identify transition strings
    my $base_pkg = $self->processable->name;
    $base_pkg =~ s/c102\b//;
    $base_pkg =~ s/c2a?\b//;
    $base_pkg =~ s/\dg$//;
    $base_pkg =~ s/gf$//;
    $base_pkg =~ s/v[5-6]$//; # GCC-5 / libstdc++6 C11 ABI breakage
    $base_pkg =~ s/-udeb$//;
    $base_pkg =~ s/^lib64/lib/;

    my $match_found = 0;
    for my $expected_name (@sonames) {
        $expected_name =~ s/([0-9])\.so\./$1-/;
        $expected_name =~ s/\.so(?:\.|\z)//;
        $expected_name =~ s/_/-/g;

        if (   (lc($expected_name) eq $self->processable->name)
            || (lc($expected_name) eq $base_pkg)) {

            $match_found = 1;
            last;
        }
    }

    $self->hint('package-name-doesnt-match-sonames', "@sonames")
      if @sonames && !$match_found && $self->processable->type ne 'udeb';

    return;
}

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless $item->file_info =~ m/^[^,]*\bELF\b/
      || $item->file_info =~ m/\bcurrent ar archive\b/;

    my $fields = $self->processable->fields;
    my $architecture = $fields->value('Architecture');

    $self->hint('arch-independent-package-contains-binary-or-object',$item)
      if $architecture eq 'all';

    $self->hint('binary-in-etc', $item)
      if $item->name =~ m{^etc/};

    $self->hint('arch-dependent-file-in-usr-share', $item)
      if $item->name =~ m{^usr/share/};

    my $multiarch = $fields->value('Multi-Arch') || 'no';

    my $gnu_triplet_pattern = $self->gnu_triplet_pattern;
    my $ruby_triplet_pattern = $self->ruby_triplet_pattern;

    $self->hint('arch-dependent-file-not-in-arch-specific-directory',$item)
      if $multiarch eq 'same'
      && length $gnu_triplet_pattern
      && $item->name !~ m{\b$gnu_triplet_pattern(?:\b|_)}
      && length $ruby_triplet_pattern
      && $item->name !~ m{/$ruby_triplet_pattern/}
      && $item->name !~ m{/java-\d+-openjdk-\Q$architecture\E/}
      && $item->name !~ m{/[.]build-id/};

    my $objdump = $self->processable->objdump_info->{$item->name};

    if ($item->file_info =~ m/\bcurrent ar archive\b/) {

        # "libfoo_g.a" is usually a "debug" library, so ignore
        # unneeded sections in those.
        return
          if $item =~ m/_g\.a$/;

        for my $obj (@{ $objdump->{objects} }) {

            my $lookup = $item->name . "($obj)";
            my $libobj = $self->processable->objdump_info->{$lookup};

            # Shouldn't happen, but...
            die encode_utf8("object ($item $obj) in static lib is missing!?")
              unless defined $libobj;

        # These are the ones file(1) looks for.  The ".zdebug_info" being the
        # compressed version of .debug_info.
        # - Technically, file(1) also looks for .symtab, but that is apparently
        #   not strippable for static libs.  Accordingly, it is omitted below.
            my @DEBUG_SECTIONS = qw{.debug_info .zdebug_info};

            if (any { exists $libobj->{SH}{$_} } @DEBUG_SECTIONS) {
                $self->hint('unstripped-static-library',$item, "($obj)");

            } else {
                my @not_needed
                  = grep { exists $libobj->{SH}{$_} }('.note', '.comment');

                $self->hint('static-library-has-unneeded-section',
                    $item, "($obj)", $_)
                  for @not_needed;
            }
        }
    }

    # ELF?
    return
      unless $item->file_info =~ /^[^,]*\bELF\b/;

    $self->hint('development-package-ships-elf-binary-in-path', $item)
      if exists $PATH_DIRECTORIES{$item->dirname}
      && $fields->value('Section') =~ m/(?:^|\/)libdevel$/
      && $fields->value('Multi-Arch') ne 'foreign';

    my $from_other_architecture = 1;

    $from_other_architecture = 0
      if $architecture eq 'all';

    # If it matches the architecture regex, it is good
    $from_other_architecture = 0
      if $self->ARCH_REGEX->recognizes($architecture)
      && $item->file_info =~ $self->ARCH_REGEX->value($architecture);

    # Special case - "old" multi-arch dirs
    if (   $item->name =~ m{(?:^|/)lib(x?\d\d)/}
        || $item->name =~ m{^emul/ia(\d\d)}) {

        my $bus_width = $1;
        $from_other_architecture = 0
          if $self->ARCH_REGEX->value($bus_width)
          && $item->file_info =~ $self->ARCH_REGEX->value($bus_width);
    }

    # Detached debug symbols could be for a biarch library.
    $from_other_architecture = 0
      if $item->name =~ m{^usr/lib/debug/\.build-id/};

    # Guile binaries do not objdump/strip (etc.) correctly.
    $from_other_architecture = 0
      if $item->name =~ $GUILE_PATH_REGEX;

    # Allow amd64 kernel modules to be installed on i386.
    if (   $item->name =~ m{^lib/modules/}
        && $self->ARCH_64BIT_EQUIVS->recognizes($architecture)) {

        my $equivalent_64 = $self->ARCH_64BIT_EQUIVS->value($architecture);
        $from_other_architecture = 0
          if $item->file_info =~ $self->ARCH_REGEX->value($equivalent_64);
    }

    # Ignore i386 binaries in amd64 packages for right now.
    $from_other_architecture = 0
      if $architecture eq 'amd64'
      && $item->file_info =~ $self->ARCH_REGEX->value('i386');

    $self->hint('binary-from-other-architecture', $item)
      if $from_other_architecture;

    my $exceptions = {
        %{ $self->group->spelling_exceptions },
        map { $_ => 1} $self->BINARY_SPELLING_EXCEPTIONS->all
    };
    my $tag_emitter
      = $self->spelling_tag_emitter('spelling-error-in-binary', $item);
    check_spelling($self->profile, $item->strings, $exceptions,
        $tag_emitter, 0);

    # stripped?
    if ($item->file_info =~ m{\bnot stripped\b}) {
        # Is it an object file (which generally cannot be
        # stripped), a kernel module, debugging symbols, or
        # perhaps a debugging package?
        unless ($item->name =~ /\.k?o$/
            || $self->processable->name =~ /-dbg$/
            || $self->processable->name =~ /debug/
            || $item->name =~ m{/lib/debug/}
            || $item->name =~ $GUILE_PATH_REGEX
            || $item->name =~ /\.gox$/) {

            if (    $item->file_info =~ m/executable/
                and $item->strings =~ m/^Caml1999X0[0-9][0-9]$/m) {

                # Check for OCaml custom executables (#498138)
                $self->hint('ocaml-custom-executable', $item);

            } else {
                $self->hint('unstripped-binary-or-object', $item);
            }
        }

    } else {

        # stripped but a debug or profiling library?
        if (   $item->name =~ m{/lib/debug/}
            || $item->name =~ m{/lib/profile/}) {
            $self->hint('stripped-library',$item)
              unless $item->size == 0;

        } else {
            # appropriately stripped, but is it stripped enough?
            my @not_needed
              = grep { exists $objdump->{SH}{$_} } qw{.note .comment};
            $self->hint('binary-has-unneeded-section',$item, $_)
              for @not_needed;
        }
    }

    # rpath is disallowed, except in private directories
    if (exists $objdump->{RPATH} || exists $objdump->{RUNPATH}) {

        my @rpaths
          = (keys %{$objdump->{RPATH}}, keys %{$objdump->{RUNPATH}});

        for my $rpath (map {File::Spec->canonpath($_)}@rpaths) {

            my $installable_name = $self->processable->name;
            my $source_name = $self->processable->source_name;

            my $madir = $self->DEB_HOST_MULTIARCH->{$architecture};
            return
              unless length $madir;

            return
              if $rpath
              =~ m{^/usr/lib/(?:$madir/)?(?:games/)?(?:\Q$installable_name\E|\Q$source_name\E)(?:/|\z)};

            return
              if $self->private_directories->{$rpath}
              && $rpath !~ m{^(?:/usr)?/lib(?:/$madir)?/?\z};

            return
              if $rpath =~ m{^\$\{?ORIGIN\}?};

            # GHC in Debian uses a scheme for RPATH. (#914873)
            return
              if $rpath =~ m{^/usr/lib/ghc/};

            $self->hint('custom-library-search-path', $item, $rpath);
        }
    }

    for my $emlib ($self->EMBEDDED_LIBRARIES->all) {
        my $ldata = $self->EMBEDDED_LIBRARIES->value($emlib);

        return
          if length $ldata->{'source-regex'}
          && $self->processable->source_name =~ $ldata->{'source-regex'};

        return
          if length $ldata->{'source-regex'}
          && $self->processable->source_name eq $ldata->{source};

        $self->hint('embedded-library', $ldata->{libname},$item->name)
          if $item->strings =~ $ldata->{match};
    }

    # binary or shared object?
    return
      unless $item->file_info =~ m{ executable | shared [ ] object }x;

    return
      if $self->processable->type eq 'udeb';

    # Perl library?
    $self->has_perl_lib(1)
      if $item->name =~ m{^usr/lib/(?:[^/]+/)?perl5/.*\.so$};

    # PHP extension?
    $self->has_php_ext(1)
      if $item->name =~ m{^usr/lib/php\d/.*\.so(?:\.\d+)*$};

    # Python extension using Numpy C ABI?
    if (   $item->name=~ m{^usr/lib/(?:pyshared/)?python2\.\d+/.*(?<!_d)\.so$}
        || $item->name
        =~ m{^ usr/lib/python3(?:[.]\d+)? / \S+ [.]cpython- \d+ - \S+ [.]so $}x
    ){
        $self->uses_numpy_c_abi(1)
          if $item->strings =~ / numpy /msx
          && $item->strings =~ $NUMPY_REGEX;
    }

    # Something other than detached debugging symbols in
    # /usr/lib/debug paths.
    if ($item->name
        =~ m{^usr/lib/debug/(?:lib\d*|s?bin|usr|opt|dev|emul|\.build-id)/}){

        $self->hint('debug-symbols-not-detached', $item)
          if exists $objdump->{NEEDED};

        $self->hint('debug-file-with-no-debug-symbols', $item)
          if none {exists $objdump->{SH}{$_} }
        qw{.debug_line .zdebug_line .debug_str .zdebug_str};
    }

    # Detached debugging symbols directly in /usr/lib/debug.
    $self->hint('debug-symbols-directly-in-usr-lib-debug', $item)
      if $item->name =~ m{^usr/lib/debug/[^/]+$}
      && !exists $objdump->{NEEDED}
      && $item->file_info !~ m/statically linked/;

    my $is_shared = $item->file_info =~ m/(shared object|pie executable)/;

    # statically linked?
    if (!exists $objdump->{NEEDED}) {
        if ($is_shared) {

            # Some exceptions: kernel modules, syslinux modules, detached
            # debugging information and the dynamic loader (which itself
            # has no dependencies).
            return
                 if $item->name =~ m{^boot/modules/}
              || $item->name =~ m{^lib/modules/}
              || $item->name =~ m{^usr/lib/debug/}
              || $item->name =~ m{\.(?:[ce]32|e64)$}
              || $item->name =~ m{^usr/lib/jvm/.*\.debuginfo$};

            return
              if $item->name =~ $GUILE_PATH_REGEX;

            return
              if $item->name =~ m{
                                  ^lib(?:|32|x32|64)/
                                   (?:[-\w/]+/)?
                                   ld-[\d.]+\.so$
                                }xsm;

            $self->hint('shared-library-lacks-prerequisites', $item);

        } else {
            # Some exceptions: files in /boot, /usr/lib/debug/*,
            # named *-static or *.static, or *-static as
            # package-name.
            return
              if $item->name =~ m{^boot/}
              || $item->name =~ /[\.-]static$/;

            return
              if $self->processable->name =~ /-static$/;

            # Binaries built by the Go compiler are statically
            # linked by default.
            return
              if $self->built_with_golang;

            # klibc binaries appear to be static.
            return
              if exists $objdump->{INTERP}
              && $objdump->{INTERP} =~ m{/lib/klibc-\S+\.so};

            # Location of debugging symbols.
            return
              if $item->name =~ m{^usr/lib/debug/};

            # ldconfig must be static.
            return
              if $item->name eq 'sbin/ldconfig';

            $self->hint('statically-linked-binary', $item);
        }

    } else {
        my $no_libc = 1;

        $self->needs_depends->{$item->name} = 1;

        my @needed = @{$objdump->{NEEDED} // []};
        for my $lib (@needed) {
            if ($lib =~ /^libc\.so\.(\d+.*)/) {
                $self->needs_libc("libc$1");
                push(@{$self->needs_libc_files}, $item->name);
                $no_libc = 0;
            }

            if ($lib =~ m{\A libstdc\+\+\.so\.(\d+) \Z}xsm) {
                $self->needs_libcxx("libstdc++$1");
                push(@{$self->needs_libcxx_files}, $item->name);
            }
        }

        # If there is no libc dependency, then it is most likely a
        # bug.  The major exception is that some C++ libraries,
        # but these tend to link against libstdc++ instead.  (see
        # #719806)
        my $linked_with_libc
          = any { /^libc[.]so[.]/ } @{$objdump->{NEEDED} // []};

        $self->hint('library-not-linked-against-libc', $item)
          if !$linked_with_libc
          && $is_shared
          && !length $self->needs_libcxx
          && $item->name !~ m{/libc\b}
          && (!$self->built_with_octave
            || $item->name !~ m/\.(?:oct|mex)$/);

        $self->hint('program-not-linked-against-libc', $item)
          if !$linked_with_libc
          && !$is_shared
          && !length $self->needs_libcxx
          && !$self->built_with_octave;

        $self->hint('hardening-no-relro', $item)
          if $self->recommended_hardening_features->{relro}
          && !$self->built_with_golang
          && !$objdump->{PH}{RELRO};

        $self->hint('hardening-no-bindnow', $item)
          if $self->recommended_hardening_features->{bindnow}
          && !$self->built_with_golang
          && !exists $objdump->{FLAGS_1}{NOW};

        $self->hint('hardening-no-pie', $item)
          if $self->recommended_hardening_features->{pie}
          && !$self->built_with_golang
          && $objdump->{'ELF-TYPE'} eq 'EXEC';
    }

    return;
}

sub breakdown_installed_files {
    my ($self) = @_;

    my $depends = $self->processable->relation('strong');

    if ($depends->is_empty) {
        $self->hint('undeclared-elf-prerequisites', $_)
          for keys %{$self->needs_depends};
    }

    # Match libcXX or libcXX-*, but not libc3p0.
    my $needs_libc = $self->needs_libc;
    if (   length $needs_libc
        && !$depends->is_empty
        && !$depends->matches(qr/^\Q$needs_libc\E\b/)) {

        my $context = 'needed by ' . @{$self->needs_libc_files}[0];
        $context
          .= ' and ' . (scalar @{$self->needs_libc_files} - 1) . ' others'
          if @{$self->needs_libc_files} > 1;

        $self->hint('missing-dependency-on-libc', $context)
          unless $self->processable->name =~ /^libc[\d.]+(?:-|\z)/;
    }

    # Match libstdc++XX or libcstdc++XX-*
    my $needs_libcxx = $self->needs_libcxx;
    if (   length $needs_libcxx
        && !$depends->is_empty
        && !$depends->matches(qr/^\Q$needs_libcxx\E\b/)) {

        my $context = 'needed by ' . @{$self->needs_libcxx_files}[0];
        $context
          .= ' and ' . (scalar @{$self->needs_libcxx_files} - 1) . ' others'
          if scalar @{$self->needs_libcxx_files} > 1;

        $self->hint('missing-dependency-on-libstdc++', $context);
    }

    # It is a virtual package, so no version is allowed and
    # alternatives probably does not make sense here either.
    $self->hint('missing-dependency-on-perlapi')
      if $self->has_perl_lib
      && !$depends->matches(
        qr/^perlapi-[-\w.]+(?:\s*\[[^\]]+\])?$/,
        Lintian::Relation::VISIT_OR_CLAUSE_FULL
      );

    # It is a virtual package, so no version is allowed and
    # alternatives probably does not make sense here either.
    $self->hint('missing-dependency-on-phpapi')
      if $self->has_php_ext
      && !$depends->matches(qr/^phpapi-[\d\w+]+$/,
        Lintian::Relation::VISIT_OR_CLAUSE_FULL);

    # Check for dependency on python3-numpy-abiN dependency (or strict
    # versioned dependency on python3-numpy)
    # We do not allow alternatives as it would mostly likely
    # defeat the purpose of this relation.  Also, we do not allow
    # versions for -abi as it is a virtual package.
    $self->hint('missing-dependency-on-numpy-abi')
      if $self->uses_numpy_c_abi
      && !$depends->matches(qr/^python3?-numpy-abi\d+$/,
        Lintian::Relation::VISIT_OR_CLAUSE_FULL)
      && (
        !$depends->matches(
            qr/^python3-numpy \(>[>=][^\|]+$/,
            Lintian::Relation::VISIT_OR_CLAUSE_FULL
        )
        || !$depends->matches(
            qr/^python3-numpy \(<[<=][^\|]+$/,
            Lintian::Relation::VISIT_OR_CLAUSE_FULL
        ))&& $self->processable->name !~ m{\A python3?-numpy \Z}xsm;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

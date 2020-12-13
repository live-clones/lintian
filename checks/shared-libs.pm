# shared-libs -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz
# Copyright © 2018-2019 Chris Lamb <lamby@debian.org>
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

package Lintian::shared_libs;

use v5.20;
use warnings;
use utf8;
use autodie;

use Const::Fast;
use File::Basename;
use List::SomeUtils qw(any none uniq);

use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SPACE => q{ };

# not presently used
#my $UNKNOWN_SHARED_LIBRARY_EXCEPTIONS
#  = $self->profile->load_data('shared-libs/unknown-shared-library-exceptions');

# List of symbols file meta-fields.
my %symbols_meta_fields = map { $_ => 1 }qw(
  Build-Depends-Package
  Build-Depends-Packages
  Ignore-Blacklist-Groups
);

sub installable {
    my ($self) = @_;

    my $pkg = $self->processable->name;
    my $type = $self->processable->type;
    my $processable = $self->processable;
    my $group = $self->group;

    my $ldconfig_dirs = $self->profile->load_data('shared-libs/ldconfig-dirs');

    my ($must_call_ldconfig, %SONAME, %SHARED_LIB_PRESENT,
        %STATIC_LIB_PRESENT, %sharedobject);
    my @shlibs;
    my @words;
    my @devpkgs;
    my $objdump = $processable->objdump_info;

    # 1st step: get info about shared libraries installed by this package
    foreach my $file (sort keys %{$objdump}) {
        $SONAME{$file} = $objdump->{$file}{SONAME}[0]
          if exists($objdump->{$file}{SONAME});
    }

    foreach my $file ($processable->installed->sorted_list) {
        $SHARED_LIB_PRESENT{$1} = 1
          if $file =~ /\/lib([^\/]+)\.so(?:\.\d+){0,3}$/;
        $STATIC_LIB_PRESENT{$1} = 1 if $file =~ m{/lib([^/]+)\.a$};
        next if not $file->is_file;
        my $fileinfo = $file->file_info;
        if (   $fileinfo =~ m/^[^,]*\bELF\b/
            && $fileinfo =~ m/(?:shared object|pie executable)/) {
            my $perm = $file->operm;
            my $debug = defined $objdump->{$file}{DEBUG};
            if ($debug and $perm & 0111 and $file !~ m/\.so(?:\.|$)/) {
                # position-independent executable
            } else {
                $sharedobject{$file} = 1;
            }
        }
    }

    if (%SONAME) {
        foreach my $bin ($group->get_binary_processables) {
            next unless $bin->name =~ m/\-dev$/;
            if ($bin->relation('strong')->implies($pkg)) {
                push @devpkgs, $bin;
            }
        }
    }

    # 2nd step: read package contents

    for my $cur_file ($processable->installed->sorted_list) {
        # shared library?

        my $normalized_target;
        $normalized_target = $cur_file->link_normalized
          if length $cur_file->link;

        if (
            exists $SONAME{$cur_file}
            or (defined $normalized_target
                and exists $SONAME{$normalized_target})
        ) {
            # yes!!
            my ($real_file, $perm);
            if (exists $SONAME{$cur_file}) {
                $real_file = $cur_file;
                $perm = $cur_file->operm;
            } else {
                $real_file = $normalized_target;
                # perm not needed for this branch
            }

            # Installed in a directory controlled by the dynamic
            # linker?  We have to strip off directories named for
            # hardware capabilities.
            if ($self->needs_ldconfig($cur_file)) {
                # yes! so postinst must call ldconfig
                $must_call_ldconfig = $real_file;
            }
            # At this point, we do not want to process symlinks as
            # they will only lead to duplicate warnings.
            next unless $cur_file eq $real_file;

            # Now that we're sure this is really a shared library, report on
            # non-PIC problems.
            if ($objdump->{$cur_file}{TEXTREL}) {
                $self->hint('specific-address-in-shared-library', $cur_file);
            }

            my @symbol_names
              = map { @{$_}[2] } @{$objdump->{$cur_file}{SYMBOLS}};
            if (   (any { m/^_?exit$/ } @symbol_names)
                && (none { $_ eq 'fork' } @symbol_names)) {
                # If it has an INTERP section it might be an application with
                # a SONAME (hi openjdk-6, see #614305).  Also see the comment
                # for "shared-library-is-executable" below.
                $self->hint('exit-in-shared-library', $cur_file)
                  unless $objdump->{$cur_file}{INTERP};
            }

            # executable?
            my $perms = sprintf('%04o', $perm);
            if ($perm & 0111) {
                # Yes.  But if the library has an INTERP section, it's
                # designed to do something useful when executed, so don't
                # report an error.  Also give ld.so a pass, since it's
                # special.
                $self->hint('shared-library-is-executable', $cur_file, $perms)
                  unless ($objdump->{$cur_file}{INTERP}
                    || $cur_file =~ m{^lib.*/ld-[\d.]+\.so$});
            } elsif ($perm != 0644) {
                $self->hint('odd-permissions-on-shared-library',
                    $cur_file, $perms);
            }

            # executable stack.
            if (not defined $objdump->{$cur_file}{'PH'}{STACK}) {
                if ($processable->fields->declares('Architecture')) {
                    my $arch = $processable->fields->value('Architecture');
                    $self->hint('shared-library-lacks-stack-section',
                        $cur_file);
                }
            } elsif ($objdump->{$cur_file}{'PH'}{STACK}{flags} ne 'rw-'){
                $self->hint('executable-stack-in-shared-library', $cur_file);
            }
        } elsif ($ldconfig_dirs->recognizes(dirname($cur_file))
            && exists $sharedobject{$cur_file}) {
            $self->hint('sharedobject-in-library-directory-missing-soname',
                $cur_file);
        } elsif ($cur_file =~ m/\.la$/ and not length $cur_file->link) {
            local $_ = undef;
            open(my $fd, '<', $cur_file->unpacked_path);
            while(<$fd>) {
                next
                  unless (m/^(libdir)='(.+?)'$/)
                  or (m/^(dependency_libs)='(.+?)'$/);
                my ($field, $value) = ($1, $2);
                if ($field eq 'libdir') {
                    # dirname with leading slash and without the trailing one.
                    my $expected = '/' . substr($cur_file->dirname, 0, -1);
                    $value =~ s{/+$}{};

                    # python-central is a special case since the
                    # libraries are moved at install time.
                    next
                      if ($value
                        =~ m{^/usr/lib/python[\d.]+/(?:site|dist)-packages}
                        and $expected =~ m{^/usr/share/pyshared});
                    $self->hint('incorrect-libdir-in-la-file', $cur_file,
                        "$value != $expected")
                      unless($expected eq $value);
                } elsif ($field eq 'dependency_libs'){
                    $self->hint('non-empty-dependency_libs-in-la-file',
                        $cur_file);
                }
            }
            close($fd);
        }
    }

    # 3rd step: check if shlib symlinks are present and in correct order
    for my $shlib_file (keys %SONAME) {
        # file found?
        if (not $processable->installed->lookup($shlib_file)) {
            die "shlib $shlib_file not found in package (should not happen!)";
        }

        my ($dir, $shlib_name) = $shlib_file =~ m{(.*)/([^/]+)$};

        # not a public shared library, skip it
        next unless $ldconfig_dirs->recognizes($dir);

        my $MA_DIRS
          = $self->profile->load_data('common/multiarch-dirs', qr/\s++/);

        # symlink found?
        my $link_file = "$dir/$SONAME{$shlib_file}";
        if (not $processable->installed->lookup($link_file)) {
            $self->hint(
                'lacks-versioned-link-to-shared-library',
                "$link_file $shlib_file $SONAME{$shlib_file}"
            );
        } else {
            # $link_file really another file?
            if ($link_file eq $shlib_file) {
                # the library file uses its SONAME, this is ok...
            } else {
                # $link_file really a symlink?
                if ($processable->installed->lookup($link_file)->is_symlink) {
                    # yes.

                    # $link_file pointing to correct file?
                    if ($processable->installed->lookup($link_file)->link eq
                        $shlib_name) {
                        # ok.
                    } else {
                        $self->hint(
                            'ldconfig-symlink-referencing-wrong-file',
                            join(q{ },
                                "$link_file ->",
                                $processable->installed->lookup($link_file)
                                  ->link,
                                "instead of $shlib_name"));
                    }
                } else {
                    $self->hint('ldconfig-symlink-is-not-a-symlink',
                        "$shlib_file $link_file");
                }
            }
        }

        # libtool "-release" variant
        $link_file =~ s/-[\d\.]+\.so$/.so/;
        # determine shlib link name (w/o version)
        $link_file =~ s/\.so.+$/.so/;

        # shlib symlink may not exist.
        # if shlib doesn't _have_ a version, then $link_file and
        # $shlib_file will be equal, and it's not a development link,
        # so don't complain.
        if (    $processable->installed->lookup($link_file)
            and $link_file ne $shlib_file) {
            $self->hint('link-to-shared-library-in-wrong-package',
                "$shlib_file $link_file");
        } elsif (@devpkgs) {
            # -dev package - it needs a shlib symlink
            my $ok = 0;
            my @alt;

            # If the shared library is in /lib, we have to look for
            # the dev symlink in /usr/lib
            $link_file = "usr/$link_file" unless $shlib_file =~ m{^usr/};

            push @alt, $link_file;

            if ($processable->source =~ /^gcc-(\d+(?:.\d+)?)$/) {
                # gcc has a lot of bi-arch libs and puts the dev symlink
                # in slightly different directories (to be co-installable
                # with itself I guess).  Allegedly, clang (etc.) have to
                # handle these special cases, so it should be
                # acceptable...
                my $gcc_ver = $1;
                my $basename = basename($link_file);
                my $madir = $MA_DIRS->value($processable->architecture);
                my @madirs;
                if (defined $madir) {
                    # For i386-*, the triplet GCC uses can be i586-* or i686-*.
                    if ($madir =~ /^i386-/) {
                        for my $n (5..6) {
                            $madir =~ s/^i./i$n/;
                            push @madirs, $madir;
                        }
                    } else {
                        push @madirs, $madir;
                    }
                }
                my @stems;
                # Generally we are looking for
                #  * usr/lib/gcc/MA-TRIPLET/$gcc_ver/${BIARCH}$basename
                #
                # Where BIARCH is one of {,64/,32/,n32/,x32/,sf/,hf/}.  Note
                # the "empty string" as a possible option.
                #
                # The two-three letter name directory before the
                # basename is bi-arch names.
                push @stems, map { "usr/lib/gcc/$_/$gcc_ver" } @madirs;
                # But in the rare case we don't know the Multi-arch dir,
                # just do without it as often (but not always) works.
                push @stems, "usr/lib/gcc/$gcc_ver" unless @madirs;

                for my $stem (@stems) {
                    push @alt,
                      map { "$stem/$_$basename" }
                      ($EMPTY, qw(64/ 32/ n32/ x32/ sf/ hf/));
                }
            }

          PKG:
            foreach my $devpkg (@devpkgs) {

                foreach my $link (@alt) {
                    if ($devpkg->installed->lookup($link)) {
                        $ok = 1;
                        last PKG;
                    }
                }
            }
            $self->hint('lacks-unversioned-link-to-shared-library',
                "$shlib_file $link_file")
              unless $ok;
        }
    }

    # 4th step: check shlibs control file
    # $version may be undef in very broken packages
    my $version = $processable->fields->value('Version');
    my $provides = $pkg;
    $provides .= "( = $version)" if length $version;
    # Assume the version to be a non-native version to avoid
    # uninitialization warnings later.
    $version = '0-1' unless length $version;
    $provides = $processable->relation('Provides')->logical_and($provides);

    my $shlibsf = $processable->control->lookup('shlibs');
    my $symbolsf = $processable->control->lookup('symbols');
    my (%shlibs_control, %symbols_control);

    # control files are not symlinks (or other "weird" things).
    $shlibsf = undef if $shlibsf and not $shlibsf->is_file;
    $symbolsf = undef if $symbolsf and not $symbolsf->is_file;

    # Libraries with no version information can't be represented by
    # the shlibs format (but can be represented by symbols).  We want
    # to warn about them if they appear in public directories.  If
    # they're in private directories, assume they're plugins or
    # private libraries and are safe.
    my %unversioned_shlibs;
    for (keys %SONAME) {
        my $soname = format_soname($SONAME{$_});
        if ($soname !~ / /) {
            $unversioned_shlibs{$_} = 1;
            $self->hint('shared-library-lacks-version', $_, $soname)
              if $ldconfig_dirs->recognizes(dirname($_));
        }
    }
    @shlibs = grep { !$unversioned_shlibs{$_} } keys %SONAME;

    if ($#shlibs == -1) {
        # no shared libraries included in package, thus shlibs control
        # file should not be present
        if ($shlibsf) {
            $self->hint('empty-shlibs');
        }
    } else {
        # shared libraries included, thus shlibs control file has to exist
        if (not $shlibsf) {
            if ($type ne 'udeb') {
                for my $shlib (@shlibs) {
                    # skip it if it's not a public shared library
                    next unless $ldconfig_dirs->recognizes(dirname($shlib));
                    $self->hint('no-shlibs', $shlib)
                      unless is_nss_plugin($shlib);
                }
            }
        } elsif ($shlibsf->is_open_ok) {
            my (%shlibs_control_used, @shlibs_depends);
            open(my $fd, '<', $shlibsf->unpacked_path);
            while (<$fd>) {
                chop;
                next if m/^\s*$/ or /^#/;

                # We exclude udebs from the checks for correct shared library
                # dependencies, since packages may contain dependencies on
                # other udeb packages.
                my $udeb = $EMPTY;
                $udeb = 'udeb: ' if s/^udeb:\s+//;
                @words = split(/\s+/, $_);
                my $shlibs_string = $udeb.$words[0].$SPACE.$words[1];
                if ($shlibs_control{$shlibs_string}) {
                    $self->hint('duplicate-in-shlibs',$shlibs_string);
                } else {
                    $shlibs_control{$shlibs_string} = 1;
                    push(@shlibs_depends, join($SPACE, @words[2 .. $#words]))
                      unless $udeb;
                }
            }
            close($fd);
            for my $shlib (@shlibs) {
                my $shlib_name = $SONAME{$shlib};
                $shlib_name = format_soname($shlib_name);
                $shlibs_control_used{$shlib_name} = 1;
                $shlibs_control_used{'udeb: '.$shlib_name} = 1;
                unless (exists $shlibs_control{$shlib_name}) {
                    # skip it if it's not a public shared library
                    next unless $ldconfig_dirs->recognizes(dirname($shlib));
                    # no!!
                    $self->hint('ships-undeclared-shared-library',
                        $shlib_name, 'for',$shlib)
                      unless is_nss_plugin($shlib);
                }
            }
            for my $shlib_name (keys %shlibs_control) {
                $self->hint('shared-library-not-shipped', $shlib_name)
                  unless $shlibs_control_used{$shlib_name};
            }

            # Check that all of the packages listed as dependencies in
            # the shlibs file are satisfied by the current package or
            # its Provides.  Normally, packages should only declare
            # dependencies in their shlibs that they themselves can
            # satisfy.
            #
            # Deduplicate the list of dependencies before warning so
            # that we don't duplicate warnings.
            @shlibs_depends = uniq(@shlibs_depends);
            for my $depend (@shlibs_depends) {
                unless ($provides->implies($depend)) {
                    $self->hint('distant-prerequisite-in-shlibs',$depend);
                }
                $self->hint('outdated-relation-in-shlibs', $depend)
                  if $depend =~ m/\(\s*[><](?![<>=])\s*/;
            }
        }
    }

    # 5th step: check symbols control file.  Add back in the unversioned shared
    # libraries, since they can still have symbols files.
    if ($#shlibs == -1 and not %unversioned_shlibs) {
        # no shared libraries included in package, thus symbols
        # control file should not be present
        if ($symbolsf) {
            $self->hint('empty-shared-library-symbols');
        }
    } elsif (not $symbolsf) {
        if ($type ne 'udeb') {
            for my $shlib (@shlibs, keys %unversioned_shlibs) {
                # skip it if it's not a public shared library
                next unless $ldconfig_dirs->recognizes(dirname($shlib));
                # Skip Objective C libraries as instance/class methods do not
                # appear in the symbol table
                next if any { @{$_}[2] =~ m/^__objc_/ }
                @{$objdump->{$shlib}{SYMBOLS}};
                $self->hint('no-symbols-control-file', $shlib)
                  unless is_nss_plugin($shlib);
            }
        }
    } elsif ($symbolsf->is_open_ok) {
        my $version_wo_rev = $version;
        $version_wo_rev =~ s/^(.+)-([^-]+)$/$1/;
        my ($full_version_count, $full_version_sym) = (0, undef);
        my ($debian_revision_count, $debian_revision_sym) = (0, undef);
        my ($soname, $dep_package, $dep);
        my %symbols_control_used;
        my @symbols_depends;
        my $dep_templates = 0;
        my %meta_info_seen;
        my $build_depends_seen = 0;
        my $warned = 0;
        my $symbol_count = 0;

        open(my $fd, '<', $symbolsf->unpacked_path);
        while (<$fd>) {
            chomp;
            next if m/^\s*$/ or /^#/;

            if (m/^([^\s|*]\S+)\s\S+\s*(?:\(\S+\s+\S+\)|\#MINVER\#)?/) {
                # soname, main dependency template

                $soname = $1;
                s/^\Q$soname\E\s*//;
                $soname = format_soname($soname);

                if ($symbols_control{$soname}) {
                    $self->hint('duplicate-entry-in-symbols-control-file',
                        $soname);
                } else {
                    $symbols_control{$soname} = 1;
                    $warned = 0;

                    foreach my $part (split /\s*,\s*/) {
                        foreach my $subpart (split /\s*\|\s*/, $part) {
                            $subpart
                              =~ m{^(\S+)(\s*(?:\(\S+\s+\S+\)|#MINVER#))?$};
                            ($dep_package, $dep) = ($1, $2 || $EMPTY);
                            if (defined $dep_package) {
                                push @symbols_depends, $dep_package . $dep;
                            } else {
                                $self->hint('syntax-error-in-symbols-file', $.)
                                  unless $warned;
                                $warned = 1;
                            }
                        }
                    }
                }

                $dep_templates = 0;
                $symbol_count = 0;
                undef %meta_info_seen;
            } elsif (m/^\|\s+\S+\s*(?:\(\S+\s+\S+\)|#MINVER#)?/) {
                # alternative dependency template

                $warned = 0;

                if (%meta_info_seen or not defined $soname) {
                    $self->hint('syntax-error-in-symbols-file', $.);
                    $warned = 1;
                }

                s/^\|\s*//;

                foreach my $part (split /\s*,\s*/) {
                    foreach my $subpart (split /\s*\|\s*/, $part) {
                        $subpart =~ m{^(\S+)(\s*(?:\(\S+\s+\S+\)|#MINVER#))?$};
                        ($dep_package, $dep) = ($1, $2 || $EMPTY);
                        if (defined $dep_package) {
                            push @symbols_depends, $dep_package . $dep;
                        } else {
                            $self->hint('syntax-error-in-symbols-file', $.)
                              unless $warned;
                            $warned = 1;
                        }
                    }
                }

                $dep_templates++ unless $warned;
            } elsif (m/^\*\s(\S+):\s\S+/) {
                # meta-information

                $self->hint('unknown-meta-field-in-symbols-file',"$1, line $.")
                  unless exists $symbols_meta_fields{$1};
                $self->hint('syntax-error-in-symbols-file', $.)
                  unless defined $soname and $symbol_count == 0;

                $meta_info_seen{$1} = 1;
                $build_depends_seen = 1 if $1 eq 'Build-Depends-Package';
            } elsif (m/^\s+(\S+)\s(\S+)(?:\s(\S+(?:\s\S+)?))?$/) {
                # Symbol definition

                $self->hint('syntax-error-in-symbols-file', $.)
                  unless defined $soname;

                $symbol_count++;
                my ($sym, $v, $dep_order) = ($1, $2, $3);
                $dep_order ||= $EMPTY;

                if (($v eq $version) and ($version =~ /-/)) {
                    $full_version_sym ||= $sym;
                    $full_version_count++;
                } elsif (($v =~ /-/)
                    and (not $v =~ /~$/)
                    and ($v ne $version_wo_rev)) {
                    $debian_revision_sym ||= $sym;
                    $debian_revision_count++;
                }

                if (length $dep_order) {
                    if ($dep_order !~ /^\d+$/ or $dep_order > $dep_templates) {
                        $self->hint('invalid-template-id-in-symbols-file', $.);
                    }
                }
            } else {
                # Unparseable line

                $self->hint('syntax-error-in-symbols-file', $.);
            }
        }
        close($fd);
        if ($full_version_count) {
            $full_version_count--;
            my $others = $EMPTY;
            if ($full_version_count > 0) {
                $others = " and $full_version_count others";
            }
            $self->hint(
                'symbols-file-contains-current-version-with-debian-revision',
                "on symbol $full_version_sym$others");
        }
        if ($debian_revision_count) {
            $debian_revision_count--;
            my $others = $EMPTY;
            if ($debian_revision_count > 0) {
                $others = " and $debian_revision_count others";
            }
            $self->hint(
                'symbols-file-contains-debian-revision',
                "on symbol $debian_revision_sym$others"
            );
        }
        for my $shlib (@shlibs, keys %unversioned_shlibs) {
            my $shlib_name = $SONAME{$shlib};
            $shlib_name = format_soname($shlib_name);
            $symbols_control_used{$shlib_name} = 1;
            $symbols_control_used{'udeb: '.$shlib_name} = 1;
            unless (exists $symbols_control{$shlib_name}) {
                # skip it if it's not a public shared library
                next unless $ldconfig_dirs->recognizes(dirname($shlib));
                $self->hint('shared-library-symbols-not-tracked',
                    $shlib_name,'for', $shlib)
                  unless is_nss_plugin($shlib);
            }
        }
        for my $shlib_name (keys %symbols_control) {
            $self->hint('surplus-shared-library-symbols',$shlib_name)
              unless $symbols_control_used{$shlib_name};
        }
        $self->hint('symbols-file-missing-build-depends-package-field')
          unless $build_depends_seen;

        # Check that all of the packages listed as dependencies in the symbols
        # file are satisfied by the current package or its Provides.
        # Normally, packages should only declare dependencies in their symbols
        # files that they themselves can satisfy.
        #
        # Deduplicate the list of dependencies before warning so that we don't
        # duplicate warnings.
        @symbols_depends = uniq(@symbols_depends);
        for my $depend (@symbols_depends) {
            my $d = $depend;
            $d =~ s/ \#MINVER\#$//;
            unless ($provides->implies($d)) {
                $self->hint('symbols-declares-dependency-on-other-package',
                    $depend);
            }
        }
    }

    # Compare the contents of the shlibs and symbols control files, but exclude
    # from this check shared libraries whose SONAMEs has no version.  Those can
    # only be represented in symbols files and aren't expected in shlibs files.
    if (keys %shlibs_control and keys %symbols_control) {
        for my $key (keys %symbols_control) {
            unless (exists $shlibs_control{$key} or $key !~ / /) {
                $self->hint('symbols-for-undeclared-shared-library', $key);
            }
        }
    }

    # 6th step: check pre- and post- control files
    if (my $preinst = $processable->control->resolve_path('preinst')) {
        if ($preinst->is_open_ok) {
            if ($preinst->bytes =~ m/^[^\#]*\bldconfig\b/m) {
                $self->hint(
                    'maintscript-calls-ldconfig', 'preinst'
                      # Assume it is needed if glibc does it
                ) if $processable->source ne 'glibc';
            }
        }
    }

    my $we_trigger_ldconfig = 0;
    if (my $postinst = $processable->control->resolve_path('postinst')) {
        if ($postinst->is_open_ok) {
            # Decide if we call ldconfig
            if ($postinst->bytes =~ m/^[^\#]*\bldconfig\b/m) {
                if ($type eq 'udeb') {
                    $self->hint('udeb-postinst-calls-ldconfig');
                } else {
                    # glibc (notably libc-bin) needs to call ldconfig in
                    # order to implement the "ldconfig" trigger.
                    $self->hint('maintscript-calls-ldconfig', 'postinst')
                      if $processable->source ne 'glibc';
                }
            }
        }
    }

    if (my $triggers = $processable->control->resolve_path('triggers')) {
        if ($triggers->is_open_ok) {
            # Determine if the package had an ldconfig trigger
            open(my $fd, '<', $triggers->unpacked_path);
            while (my $line = <$fd>) {

                # trim both ends
                $line =~ s/^\s+|\s+$//g;

                $line =~ tr/ \t/ /s;
                if ($line eq 'activate-noawait ldconfig') {
                    $we_trigger_ldconfig=1;
                    last;
                }
            }
            close($fd);
        }
    }

    if ($type eq 'udeb') {
        $self->hint('udeb-postinst-must-not-call-ldconfig')
          if $we_trigger_ldconfig;
    } else {
        $self->hint('package-has-unnecessary-activation-of-ldconfig-trigger')
          if $we_trigger_ldconfig and not $must_call_ldconfig;
        $self->hint('lacks-ldconfig-trigger',$must_call_ldconfig)
          if not $we_trigger_ldconfig and $must_call_ldconfig;
    }

    my $multiarch = $processable->fields->value('Multi-Arch') || 'no';
    if ($multiarch eq 'foreign' and $must_call_ldconfig) {
        $self->hint('shared-library-is-multi-arch-foreign',
            $must_call_ldconfig);
    }

    if (my $prerm = $processable->control->resolve_path('prerm')) {
        if ($prerm->is_open_ok) {
            if ($prerm->bytes =~ m/^[^\#]*\bldconfig\b/m) {
                $self->hint(
                    'maintscript-calls-ldconfig', 'prerm'
                      # Assume it is needed if glibc does it
                ) if $processable->source ne 'glibc';
            }
        }
    }

    if (my $postrm = $processable->control->resolve_path('postrm')) {
        if ($postrm->is_open_ok) {
            my $contents = $postrm->bytes;

            # Decide if we call ldconfig
            if ($contents =~ m/^[^\#]*\bldconfig\b/m) {
                $self->hint(
                    'maintscript-calls-ldconfig', 'postrm'
                      # Assume it is needed if glibc does it
                ) if $processable->source ne 'glibc';
            }
        }
    }

    return;
}

# Extract the library name and the version from an SONAME and return them
# separated by a space.  This code should match the split_soname function in
# dpkg-shlibdeps.
sub format_soname {
    my $soname = shift;

    # libfoo.so.X.X
    if ($soname =~ /^(.*)\.so\.(.*)$/) {
        $soname = "$1 $2";
        # libfoo-X.X.so
    } elsif ($soname =~ /^(.*)-(\d.*)\.so$/) {
        $soname = "$1 $2";
    }

    return $soname;
}

# Returns a truth value if the first argument appears to be the path
# to a libc nss plugin (libnss_<name>.so.$version).
sub is_nss_plugin {
    my ($path) = @_;

    return 1
      if $path =~ m{^(.*/)?libnss_[^.]+\.so\.\d+$};

    return 0;
}

sub needs_ldconfig {
    my ($self, $file) = @_;

   # Libraries that should only be used in the presence of certain capabilities
   # may be located in subdirectories of the standard ldconfig search path with
   # one of the following names.
    my $HWCAP_DIRS = $self->profile->load_data('shared-libs/hwcap-dirs');
    my $ldconfig_dirs = $self->profile->load_data('shared-libs/ldconfig-dirs');

    my $dirname = dirname($file);
    my $encapsulator;
    do {
        $dirname =~ s{/([^/]+)$}{};
        $encapsulator = $1;

    } while ($encapsulator && $HWCAP_DIRS->recognizes($encapsulator));

    $dirname .= "/$encapsulator" if $encapsulator;

    # yes! so postinst must call ldconfig
    return 1
      if $ldconfig_dirs->recognizes($dirname);

    return 0;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

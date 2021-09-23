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

package Lintian::Check::SharedLibs;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Basename;
use List::SomeUtils qw(any none uniq);
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $SLASH => q{/};
const my $ARROW => q{->};

const my $WIDELY_READABLE => oct(644);

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

    # 1st step: get info about shared libraries installed by this package
    my $objdump = $self->processable->objdump_info;

    my %SONAME;
    for my $path (sort keys %{$objdump}) {

        $SONAME{$path} = $objdump->{$path}{SONAME}[0]
          if exists($objdump->{$path}{SONAME});
    }

    my $installed = $self->processable->installed;

    die encode_utf8("shlib $_ not found")
      for grep { !defined $installed->lookup($_) } keys %SONAME;

    my %sharedobject;
    for my $file (@{$installed->sorted_list}) {

        next
          unless $file->file_info =~ m/^[^,]*\bELF\b/
          && $file->file_info =~ m/(?:shared object|pie executable)/;

        # disregard position-independent executables
        $sharedobject{$file} = 1
          if !$file->is_executable
          || !defined $objdump->{$file}{DEBUG}
          || $file->name =~ / [.]so (?: [.] | $ ) /msx;
    }

    my @devpkgs;
    if (%SONAME) {
        for my $installable ($self->group->get_binary_processables) {

            push(@devpkgs, $installable)
              if $installable->name =~ /-dev$/
              && $installable->relation('strong')
              ->implies($self->processable->name);
        }
    }

    # 2nd step: read package contents
    my $fields = $self->processable->fields;
    my $control = $self->processable->control;

    my @ldconfig_folders = @{$self->profile->architectures->ldconfig_folders};
    my $must_call_ldconfig;

    for my $item (@{$installed->sorted_list}) {

        my $normalized_target;
        $normalized_target = $item->link_normalized
          if length $item->link;

        if (
            exists $SONAME{$item->name}
            || (defined $normalized_target
                && exists $SONAME{$normalized_target})
        ) {
            # shared library
            my $real_file;
            if (exists $SONAME{$item->name}) {
                $real_file = $item;
            } else {
                $real_file = $normalized_target;
            }

            # Installed in a directory controlled by the dynamic
            # linker?  We have to strip off directories named for
            # hardware capabilities.
            # yes! so postinst must call ldconfig
            $must_call_ldconfig = $real_file
              if $self->needs_ldconfig($item);

            # At this point, we do not want to process symlinks as
            # they will only lead to duplicate warnings.
            next
              unless $item eq $real_file;

            # Now that we're sure this is really a shared library, report on
            # non-PIC problems.
            $self->hint('specific-address-in-shared-library', $item->name)
              if $objdump->{$item->name}{TEXTREL};

            my @symbol_names
              = map { @{$_}[2] } @{$objdump->{$item->name}{SYMBOLS}};
            if (   (any { m/^_?exit$/ } @symbol_names)
                && (none { $_ eq 'fork' } @symbol_names)) {

                # If it has an INTERP section it might be an application with
                # a SONAME (hi openjdk-6, see #614305).  Also see the comment
                # for "shared-library-is-executable" below.
                $self->hint('exit-in-shared-library', $item->name)
                  unless $objdump->{$item->name}{INTERP};
            }

            # Yes.  But if the library has an INTERP section, it's
            # designed to do something useful when executed, so don't
            # report an error.  Also give ld.so a pass, since it's
            # special.
            $self->hint('shared-library-is-executable',
                $item->name, $item->octal_permissions)
              if $item->is_executable
              && !$objdump->{$item->name}{INTERP}
              && $item->name !~ m{^lib.*/ld-[\d.]+\.so$};

            $self->hint('odd-permissions-on-shared-library',
                $item->name, $item->octal_permissions)
              if !$item->is_executable
              && $item->operm != $WIDELY_READABLE;

            $self->hint('shared-library-lacks-stack-section',$item->name)
              if $fields->declares('Architecture')
              && !exists $objdump->{$item->name}{'PH'}{STACK};

            $self->hint('executable-stack-in-shared-library', $item->name)
              if exists $objdump->{$item->name}{'PH'}{STACK}
              && $objdump->{$item->name}{'PH'}{STACK}{flags} ne 'rw-';

        } elsif ((any { $item->dirname eq $_ } @ldconfig_folders)
            && exists $sharedobject{$item->name}) {
            $self->hint('sharedobject-in-library-directory-missing-soname',
                $item->name);

        } elsif ($item->name =~ /[.]la$/ && !length $item->link) {
            $self->check_la_file($item);
        }
    }

    # 3rd step: check if shlib symlinks are present and in correct order
    for my $path (keys %SONAME) {

        my ($dirname, $basename) = ($path =~ m{^ (.*/) ([^/]+) $}x);

        # skip non-public libraries
        next
          unless any { $dirname eq $_ } @ldconfig_folders;

        my $soname = $SONAME{$path};
        my $versioned = $dirname . $soname;

        $self->hint('lacks-versioned-link-to-shared-library',
            $versioned, $path, $soname)
          unless defined $installed->lookup($versioned);

        $self->hint(
            'ldconfig-symlink-referencing-wrong-file',
            $versioned, $ARROW,$installed->lookup($versioned)->link,
            'instead of', $basename
          )
          if $versioned ne $path
          && defined $installed->lookup($versioned)
          && $installed->lookup($versioned)->is_symlink
          && $installed->lookup($versioned)->link ne $basename;

        $self->hint('ldconfig-symlink-is-not-a-symlink',$path, $versioned)
          if $versioned ne $path
          && defined $installed->lookup($versioned)
          && !$installed->lookup($versioned)->is_symlink;

        my $unversioned = $versioned;
        # libtool "-release" variant
        $unversioned =~ s/-[\d\.]+\.so$/.so/;
        # determine shlib link name (w/o version)
        $unversioned =~ s/\.so.+$/.so/;

        # shlib symlink may not exist.
        # if shlib doesn't _have_ a version, then $unversioned and
        # $path will be equal, and it's not a development link,
        # so don't complain.
        if (defined $installed->lookup($unversioned)
            && $unversioned ne $path) {

            $self->hint('link-to-shared-library-in-wrong-package',
                $path, $unversioned);

        } elsif (@devpkgs) {
            # -dev package - it needs a shlib symlink
            my $ok = 0;
            my @alt;

            # If the shared library is in /lib, we have to look for
            # the dev symlink in /usr/lib
            $unversioned = "usr/$unversioned" unless $path =~ m{^usr/};

            push @alt, $unversioned;

            if ($self->processable->source_name =~ /^gcc-(\d+(?:.\d+)?)$/) {
                # gcc has a lot of bi-arch libs and puts the dev symlink
                # in slightly different directories (to be co-installable
                # with itself I guess).  Allegedly, clang (etc.) have to
                # handle these special cases, so it should be
                # acceptable...
                my $gcc_ver = $1;
                my $link_basename = basename($unversioned);

                my $DEB_HOST_MULTIARCH
                  = $self->profile->architectures->deb_host_multiarch;

                my $madir
                  = $DEB_HOST_MULTIARCH->{$self->processable->architecture};

                my @madirs;
                if (defined $madir) {
                    # For i386-*, the triplet GCC uses can be i586-* or i686-*.
                    if ($madir =~ /^i386-/) {
                        my $five = $madir;
                        $five =~ s/^ i. /i5/msx;
                        my $six = $madir;
                        $six =~ s/^ i. /i6/msx;
                        push(@madirs, $five, $six);

                    } else {
                        push @madirs, $madir;
                    }
                }

                my @stems;
                # Generally we are looking for
                #  * usr/lib/gcc/MA-TRIPLET/$gcc_ver/${BIARCH}$link_basename
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
                      map { "$stem/$_$link_basename" }
                      ($EMPTY, qw(64/ 32/ n32/ x32/ sf/ hf/));
                }
            }

            for my $devpkg (@devpkgs) {

                if (any { defined $devpkg->installed->lookup($_) } @alt) {

                    $ok = 1;
                    last;
                }
            }

            $self->hint('lacks-unversioned-link-to-shared-library',
                $path, $unversioned)
              unless $ok;
        }
    }

    # 4th step: check shlibs control file
    # $package_version may be undef in very broken packages
    my $package_version = $fields->value('Version');
    my $provides = $self->processable->name;
    $provides .= "( = $package_version)" if length $package_version;

    # Assume the version to be a non-native version to avoid
    # uninitialization warnings later.
    $package_version = '0-1' unless length $package_version;
    $provides
      = $self->processable->relation('Provides')->logical_and($provides);

    my $shlibsf = $control->lookup('shlibs');
    $shlibsf = undef
      if defined $shlibsf && !$shlibsf->is_file;

    my $symbolsf = $control->lookup('symbols');
    $symbolsf = undef
      if defined $symbolsf && !$symbolsf->is_file;

    my %shlibs_control;
    my %symbols_control;

    # Libraries with no version information can't be represented by
    # the shlibs format (but can be represented by symbols).  We want
    # to warn about them if they appear in public directories.  If
    # they're in private directories, assume they're plugins or
    # private libraries and are safe.
    my %unversioned_shlibs;
    for my $key (keys %SONAME) {

        my $soname = format_soname($SONAME{$key});
        next
          if $soname =~ / /;

        $unversioned_shlibs{$key} = 1;
        $self->hint('shared-library-lacks-version', $key, $soname)
          if any { (dirname($key) . $SLASH) eq $_ } @ldconfig_folders;
    }

    my @shared_library_paths = grep { !$unversioned_shlibs{$_} } keys %SONAME;

    # no shared libraries included in package, thus shlibs control
    # file should not be present
    $self->hint('empty-shlibs')
      if defined $shlibsf && !@shared_library_paths;

    # shared libraries included, thus shlibs control file has to exist
    for my $path (@shared_library_paths) {

        # skip it if it's not a public shared library
        next
          unless any { (dirname($path) . $SLASH) eq $_ } @ldconfig_folders;

        $self->hint('no-shlibs', $path)
          unless defined $shlibsf
          || $self->processable->type eq 'udeb'
          || is_nss_plugin($path);
    }

    if (@shared_library_paths && defined $shlibsf) {

        my @shlibs_depends;

        my @lines = split(/\n/, $shlibsf->decoded_utf8);

        my $position = 1;
        for my $line (@lines) {

            next
              if $line =~ /^\s*$/
              || $line =~ /^#/;

            # We exclude udebs from the checks for correct shared library
            # dependencies, since packages may contain dependencies on
            # other udeb packages.

            my $udeb = $EMPTY;
            $udeb = 'udeb: '
              if $line =~ s/^udeb:\s+//;

            my ($name, $version, @prerequisites) = split(/\s+/, $line);
            my $shlibs_string = "$udeb$name $version";

            if (exists $shlibs_control{$shlibs_string}) {
                $self->hint('duplicate-in-shlibs', "(line $position)",
                    $shlibs_string);
                next;
            }

            $shlibs_control{$shlibs_string} = 1;
            push(@shlibs_depends, join($SPACE, @prerequisites))
              unless $udeb;

        } continue {
            ++$position;
        }

        my %shlibs_control_used;
        for my $path (@shared_library_paths) {

            my $soname = format_soname($SONAME{$path});

            $shlibs_control_used{$soname} = 1;
            $shlibs_control_used{'udeb: '.$soname} = 1;

            unless (exists $shlibs_control{$soname}) {
                # skip it if it's not a public shared library
                next
                  unless any { (dirname($path) . $SLASH) eq $_ }
                @ldconfig_folders;

                # no!!
                $self->hint('ships-undeclared-shared-library',
                    $soname, 'for', $path)
                  unless is_nss_plugin($path);
            }
        }

        for my $soname (keys %shlibs_control) {
            $self->hint('shared-library-not-shipped', $soname)
              unless $shlibs_control_used{$soname};
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

            $self->hint('distant-prerequisite-in-shlibs',$depend)
              unless $provides->implies($depend);

            $self->hint('outdated-relation-in-shlibs', $depend)
              if $depend =~ m/\(\s*[><](?![<>=])\s*/;
        }
    }

    # 5th step: check symbols control file.  Add back in the unversioned shared
    # libraries, since they can still have symbols files.
    if (!@shared_library_paths && !%unversioned_shlibs) {
        # no shared libraries included in package, thus symbols
        # control file should not be present
        $self->hint('empty-shared-library-symbols')
          if defined $symbolsf;

    } elsif (not $symbolsf) {
        if ($self->processable->type ne 'udeb') {
            for my $path (@shared_library_paths, keys %unversioned_shlibs) {
                # skip it if it's not a public shared library
                next
                  unless any { (dirname($path) . $SLASH) eq $_ }
                @ldconfig_folders;

                # Skip Objective C libraries as instance/class methods do not
                # appear in the symbol table
                next if any { @{$_}[2] =~ m/^__objc_/ }
                @{$objdump->{$path}{SYMBOLS}};
                $self->hint('no-symbols-control-file', $path)
                  unless is_nss_plugin($path);
            }
        }

    } else {
        my $package_version_wo_rev = $package_version;
        $package_version_wo_rev =~ s/^(.+)-([^-]+)$/$1/;

        my $full_version_count = 0;
        my $full_version_sym;
        my $debian_revision_count = 0;
        my $debian_revision_sym;
        my $soname;
        my %symbols_control_used;
        my @symbols_depends;
        my $dep_templates = 0;
        my %meta_info_seen;
        my $build_depends_seen = 0;
        my $warned = 0;
        my $symbol_count = 0;

        my @lines = split(/\n/, $symbolsf->decoded_utf8);

        my $position = 1;
        for my $line (@lines) {

            next
              if $line =~ /^\s*$/
              || $line =~ /^#/;

            if ($line =~ /^([^\s|*]\S+)\s\S+\s*(?:\(\S+\s+\S+\)|\#MINVER\#)?/){
                # soname, main dependency template

                $soname = $1;
                $line =~ s/^\Q$soname\E\s*//;
                $soname = format_soname($soname);

                if ($symbols_control{$soname}) {
                    $self->hint('duplicate-entry-in-symbols-control-file',
                        "(line $position)", $soname);
                } else {
                    $symbols_control{$soname} = 1;
                    $warned = 0;

                    for my $part (split(/\s*,\s*/, $line)) {
                        for my $subpart (split /\s*\|\s*/, $part) {

                            $subpart
                              =~ m{^(\S+)(\s*(?:\(\S+\s+\S+\)|#MINVER#))?$};
                            my ($dep_package, $dep) = ($1, $2 || $EMPTY);

                            if (defined $dep_package) {
                                push @symbols_depends, $dep_package . $dep;

                            } else {
                                $self->hint('syntax-error-in-symbols-file',
                                    "(line $position)")
                                  unless $warned;
                                $warned = 1;
                            }
                        }
                    }
                }

                $dep_templates = 0;
                $symbol_count = 0;
                undef %meta_info_seen;

            } elsif ($line =~ /^\|\s+\S+\s*(?:\(\S+\s+\S+\)|#MINVER#)?/) {
                # alternative dependency template

                $warned = 0;

                if (%meta_info_seen or not defined $soname) {
                    $self->hint('syntax-error-in-symbols-file',
                        "(line $position)");
                    $warned = 1;
                }

                $line =~ s/^\|\s*//;

                for my $part (split(/\s*,\s*/, $line)) {
                    for my $subpart (split /\s*\|\s*/, $part) {
                        $subpart =~ m{^(\S+)(\s*(?:\(\S+\s+\S+\)|#MINVER#))?$};
                        my ($dep_package, $dep) = ($1, $2 || $EMPTY);

                        if (defined $dep_package) {
                            push @symbols_depends, $dep_package . $dep;
                        } else {
                            $self->hint('syntax-error-in-symbols-file',
                                "(line $position)")
                              unless $warned;
                            $warned = 1;
                        }
                    }
                }

                $dep_templates++ unless $warned;

            } elsif ($line =~ /^\*\s(\S+):\s\S+/) {
                # meta-information

                $self->hint('unknown-meta-field-in-symbols-file',
                    "(line $position)", $1)
                  unless exists $symbols_meta_fields{$1};

                $self->hint('syntax-error-in-symbols-file', "(line $position)")
                  unless defined $soname and $symbol_count == 0;

                $meta_info_seen{$1} = 1;
                $build_depends_seen = 1
                  if $1 eq 'Build-Depends-Package';

            } elsif ($line =~ /^\s+(\S+)\s(\S+)(?:\s(\S+(?:\s\S+)?))?$/) {
                # Symbol definition

                $self->hint('syntax-error-in-symbols-file', "(line $position)")
                  unless defined $soname;

                $symbol_count++;
                my ($sym, $v, $dep_order) = ($1, $2, $3);
                $dep_order ||= $EMPTY;

                if (($v eq $package_version) and ($package_version =~ /-/)) {
                    $full_version_sym ||= $sym;
                    $full_version_count++;

                } elsif (($v =~ /-/)
                    and (not $v =~ /~$/)
                    and ($v ne $package_version_wo_rev)) {

                    $debian_revision_sym ||= $sym;
                    $debian_revision_count++;
                }

                if (length $dep_order) {
                    if ($dep_order !~ /^\d+$/ or $dep_order > $dep_templates) {
                        $self->hint('invalid-template-id-in-symbols-file',
                            "(line $position)");
                    }
                }

            } else {
                # Unparseable line
                $self->hint('syntax-error-in-symbols-file',"(line $position)");
            }

        } continue {
            ++$position;
        }

        if ($full_version_count) {
            $full_version_count--;

            my $others = $EMPTY;
            $others = " and $full_version_count others"
              if $full_version_count > 0;

            $self->hint(
                'symbols-file-contains-current-version-with-debian-revision',
                "on symbol $full_version_sym$others");
        }

        if ($debian_revision_count) {
            $debian_revision_count--;

            my $others = $EMPTY;
            $others = " and $debian_revision_count others"
              if $debian_revision_count > 0;

            $self->hint(
                'symbols-file-contains-debian-revision',
                "on symbol $debian_revision_sym$others"
            );
        }

        for my $path (@shared_library_paths, keys %unversioned_shlibs) {

            $soname = format_soname($SONAME{$path});
            $symbols_control_used{$soname} = 1;
            $symbols_control_used{'udeb: '.$soname} = 1;

            unless (exists $symbols_control{$soname}) {
                # skip it if it's not a public shared library
                next
                  unless any { (dirname($path) . $SLASH) eq $_ }
                @ldconfig_folders;

                $self->hint('shared-library-symbols-not-tracked',
                    $soname,'for', $path)
                  unless is_nss_plugin($path);
            }
        }

        for my $soname (keys %symbols_control) {
            $self->hint('surplus-shared-library-symbols',$soname)
              unless $symbols_control_used{$soname};
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

        for my $prerequisite (uniq @symbols_depends) {

            $prerequisite =~ s/ [ ] [#] MINVER [#] $//x;
            $self->hint('symbols-declares-dependency-on-other-package',
                $prerequisite)
              unless $provides->implies($prerequisite);
        }
    }

    # Compare the contents of the shlibs and symbols control files, but exclude
    # from this check shared libraries whose SONAMEs has no version.  Those can
    # only be represented in symbols files and aren't expected in shlibs files.
    if (keys %shlibs_control) {
        for my $key (keys %symbols_control) {

            next
              unless $key =~ / /;

            $self->hint('symbols-for-undeclared-shared-library', $key)
              unless exists $shlibs_control{$key};
        }
    }

    # 6th step: check pre- and post- control files
    my @deb_scripts = qw{preinst postinst prerm postrm};
    my @calls_ldconfig;

    for my $path (@deb_scripts) {

        my $item = $control->resolve_path($path);
        next
          unless defined $item;

        push(@calls_ldconfig, $path)
          if $item->decoded_utf8 =~ /^ [^\#]* \b ldconfig \b /mx;
    }

    for my $path (@calls_ldconfig) {

        if ($self->processable->type eq 'udeb' && $path eq 'postinst') {
            $self->hint('udeb-postinst-calls-ldconfig');

        } else {
            $self->hint('maintscript-calls-ldconfig', $path);
        }
    }

    # determine if the package had an ldconfig trigger
    my $triggers = $control->resolve_path('triggers');

    my $we_trigger_ldconfig = 0;
    $we_trigger_ldconfig = 1
      if defined $triggers
      && $triggers->decoded_utf8
      =~ /^ \s* activate-noawait \s+ ldconfig \s* $/mx;

    $self->hint('udeb-postinst-must-not-call-ldconfig')
      if $self->processable->type eq 'udeb'
      && $we_trigger_ldconfig;

    $self->hint('package-has-unnecessary-activation-of-ldconfig-trigger')
      if !$must_call_ldconfig
      && $we_trigger_ldconfig
      && $self->processable->type ne 'udeb';

    $self->hint('lacks-ldconfig-trigger', $must_call_ldconfig)
      if $must_call_ldconfig
      && !$we_trigger_ldconfig
      && $self->processable->type ne 'udeb';

    $self->hint('shared-library-is-multi-arch-foreign',$must_call_ldconfig)
      if $fields->value('Multi-Arch') eq 'foreign'
      && $must_call_ldconfig;

    return;
}

sub check_la_file {
    my ($self, $file) = @_;

    my @lines = split(/\n/, $file->decoded_utf8);

    my $position = 1;
    for my $line (@lines) {

        if ($line =~ /^ libdir=' (.+) ' $/x) {

            my $value = $1;
            $value =~ s{/+$}{};

            # dirname with leading slash and without the trailing one.
            my $expected = $SLASH . $file->dirname;
            $expected =~ s{ /$ }{}msx;

            # python-central is a special case since the
            # libraries are moved at install time.
            next
              if (  $value=~ m{^/usr/lib/python[\d.]+/(?:site|dist)-packages}
                and $expected =~ m{^/usr/share/pyshared});

            $self->hint(
                'incorrect-libdir-in-la-file', $file,
                "(line $position)",
                "$value != $expected"
            )unless $expected eq $value;

        } elsif ($line =~ /^ dependency_libs=' (.+) ' $/x){

            my $value = $1;
            $self->hint('non-empty-dependency_libs-in-la-file',
                $file, "(line $position)", $value);
        }

    } continue {
        ++$position;
    }

    return;
}

# Extract the library name and the version from an SONAME and return them
# separated by a space.  This code should match the split_soname function in
# dpkg-shlibdeps.
sub format_soname {
    my ($soname) = @_;

    if ($soname =~ /^(.*)\.so\.(.*)$/) {
        # libfoo.so.X.X
        $soname = "$1 $2";

    } elsif ($soname =~ /^(.*)-(\d.*)\.so$/) {
        # libfoo-X.X.so
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
    my @ldconfig_folders = @{$self->profile->architectures->ldconfig_folders};

    my $dirname = $file->dirname;
    my $encapsulator;
    do {
        $dirname =~ s{ ([^/]+) / $}{}x;
        $encapsulator = $1;

    } while ($encapsulator && $HWCAP_DIRS->recognizes($encapsulator));

    $dirname .= "$encapsulator/" if $encapsulator;

    # yes! so postinst must call ldconfig
    return 1
      if any { $dirname eq $_ } @ldconfig_folders;

    return 0;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# languages/java -- lintian check script -*- perl -*-

# Copyright © 2011 Vincent Fourmond
# Copyright © 2021 Felix Lechner
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

package Lintian::Check::Languages::Java;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Basename;
use List::SomeUtils qw(any none);

use Lintian::Util qw(normalize_link_target $PKGNAME_REGEX $PKGVERSION_REGEX);

const my $EMPTY => q{};
const my $HYPHEN => q{-};

const my $ARROW => q{->};

const my $BYTE_CODE_VERSION_OFFSET => 44;

use Moo;
use namespace::clean;

with 'Lintian::Check';

our $CLASS_REGEX = qr/\.(?:class|cljc?)/;

sub visit_patched_files {
    my ($self, $item) = @_;

    my $java_info = $item->java_info;
    return
      unless scalar keys %{$java_info};

    my $files = $java_info->{files};

    $self->pointed_hint('source-contains-prebuilt-java-object', $item->pointer)
      if any { m/$CLASS_REGEX$/i } keys %{$files};

    return;
}

sub installable {
    my ($self) = @_;

    my $missing_jarwrapper = 0;
    my $has_public_jars = 0;
    my $jmajlow = $HYPHEN;

    my $depends = $self->processable->relation('strong')->to_string;

    # Remove all libX-java-doc packages to avoid thinking they are java libs
    #  - note the result may not be a valid dependency listing
    $depends =~ s/lib[^\s,]+-java-doc//g;

    my @java_lib_depends = ($depends =~ m/\b(lib[^\s,]+-java)\b/g);

    my $MAX_BYTECODE= $self->data->load('java/constants', qr/\s*=\s*/);

    # We first loop over jar files to find problems

    for my $item (@{$self->processable->installed->sorted_list}) {

        my $java_info = $item->java_info;
        next
          unless scalar keys %{$java_info};

        my $files = $java_info->{files};
        my $manifest = $java_info->{manifest};
        my $jar_dir = dirname($item->name);
        my $classes = 0;
        my $datafiles = 1;
        my $class_path = $EMPTY;
        my $bsname = $EMPTY;

        if (exists $java_info->{error}) {
            $self->pointed_hint('zip-parse-error', $item->pointer,
                $java_info->{error});
            next;
        }

        # The Java Policy says very little about requires for (jars in) JVMs
        next
          if $item->name =~ m{^usr/lib/jvm(?:-exports)?/[^/]+/};

        # Ignore Mozilla's jar files, see #635495
        next
          if $item->name =~ m{^usr/lib/xul(?:-ext|runner[^/]*+)/};

        if ($item->name =~ m{^usr/share/java/[^/]+\.jar$}) {
            $has_public_jars = 1;

            # java policy requires package version too; see Bug#976681
            $self->pointed_hint('bad-jar-name', $item->pointer)
              unless basename($item->name)
              =~ /^$PKGNAME_REGEX-$PKGVERSION_REGEX\.jar$/;
        }

        # check for common code files like .class or .clj (Clojure files)
        for my $class (grep { m/$CLASS_REGEX$/i } sort keys %{$files}){

            my $module_version = $files->{$class};
            (my $src = $class) =~ s/\.[^.]+$/\.java/;

            $self->pointed_hint('jar-contains-source', $item->pointer, $src)
              if %{$files}{$src};

            $classes = 1;

            next
              if $class =~ m/\.cljc?$/;

            # .class but no major version?
            next
              if $module_version eq $HYPHEN;

            if ($module_version
                <= $MAX_BYTECODE->value('min-bytecode-version') - 1
                || $module_version
                > $MAX_BYTECODE->value('max-bytecode-existing-version')) {

                # First public major version was 45 (Java1), latest
                # version is 55 (Java11).
                $self->pointed_hint('unknown-java-class-version',
                    $item->pointer,$class, $ARROW, $module_version);

                # Skip the rest of this Jar.
                last;
            }

            # Collect the "lowest" Class version used.  We assume that
            # mixed class formats implies special compat code for certain
            # JVM cases.
            if ($jmajlow eq $HYPHEN) {
                # first;
                $jmajlow = $module_version;

            } else {
                $jmajlow = $module_version
                  if $module_version < $jmajlow;
            }
        }

        $datafiles = 0
          if none { /\.(?:xml|properties|x?html|xhp)$/i } keys %{$files};

        if ($item->is_executable) {

            $self->pointed_hint('executable-jar-without-main-class',
                $item->pointer)
              unless $manifest && $manifest->{'Main-Class'};

            # Here, we need to check that the package depends on
            # jarwrapper.
            $missing_jarwrapper = 1
              unless $self->processable->relation('strong')
              ->satisfies('jarwrapper');

        } elsif ($item->name !~ m{^usr/share/}) {

            $self->pointed_hint('jar-not-in-usr-share', $item->pointer);
        }

        $class_path = $manifest->{'Class-Path'}//$EMPTY if $manifest;
        $bsname = $manifest->{'Bundle-SymbolicName'}//$EMPTY if $manifest;

        if ($manifest) {
            if (!$classes) {

               # Eclipse / OSGi bundles are sometimes source bundles
               #   these do not ship classes but java files and other sources.
               # Javadoc jars deployed in the Maven repository also do not ship
               #   classes but HTML files, images and CSS files
                if ((
                           $bsname !~ m/\.source$/
                        && $item->name
                        !~ m{^usr/share/maven-repo/.*-javadoc\.jar}
                        && $item->name !~ m{\.doc(?:\.(?:user|isv))?_[^/]+.jar}
                        && $item->name !~ m{\.source_[^/]+.jar}
                    )
                    || $class_path
                ) {
                    $self->pointed_hint('codeless-jar', $item->pointer);
                }
            }

        } elsif ($classes) {
            $self->pointed_hint('missing-manifest', $item->pointer);
        }

        if ($class_path) {
            # Only run the tests when a classpath is present
            my @relative;
            my @paths = split(m/\s++/, $class_path);
            for my $p (@paths) {
                if ($p) {
                    # Strip leading ./
                    $p =~ s{^\./+}{}g;
                    if ($p !~ m{^(?:file://)?/} && $p =~ m{/}) {
                        my $target = normalize_link_target($jar_dir, $p);
                        my $tinfo;
                        # Can it be normalized?
                        next unless defined($target);
                        # Relative link to usr/share/java ? Works if
                        # we are depending of a Java library.
                        next
                          if $target =~ m{^usr/share/java/[^/]+.jar$}
                          && @java_lib_depends;
                        $tinfo= $self->processable->installed->lookup($target);
                        # Points to file or link in this package,
                        #  which is sometimes easier than
                        #  re-writing the classpath.
                        next
                          if defined $tinfo
                          and ($tinfo->is_symlink or $tinfo->is_file);
                        # Relative path with subdirectories.
                        push @relative, $p;
                    }
                    # @todo add an info tag for relative paths, to educate
                    # maintainers ?
                }
            }

            $self->pointed_hint('classpath-contains-relative-path',
                $item->pointer, join(', ', @relative))
              if @relative;
        }

        # Trigger a warning when a maven plugin lib is installed in
        # /usr/share/java/
        $self->pointed_hint('maven-plugin-in-usr-share-java', $item->pointer)
          if    $has_public_jars
          && $self->processable->name =~ /^lib.*maven.*plugin.*/
          && $item->name !~ m{^usr/share/maven-repo/.*\.jar};
    }

    $self->hint('missing-dep-on-jarwrapper') if $missing_jarwrapper;

    if ($jmajlow ne $HYPHEN) {
        # Byte code numbers:
        #  45-49 -> Java1 - Java5 (Always ok)
        #     50 -> Java6
        #     51 -> Java7
        #     52 -> Java8
        #     53 -> Java9
        #     54 -> Java10
        #     55 -> Java11
        my $bad = 0;

        # If the lowest version used is greater than the requested
        # limit, then flag it.
        $bad = 1
          if $jmajlow > $MAX_BYTECODE->value('max-bytecode-version');

        # Technically we ought to do some checks with Java6 class
        # files and dependencies/package types, but for now just skip
        # that.  (See #673276)

        if ($bad) {
            # Map the Class version to a Java version.
            my $java_version = $jmajlow - $BYTE_CODE_VERSION_OFFSET;

            $self->hint('incompatible-java-bytecode-format',
                "Java$java_version version (Class format: $jmajlow)");
        }
    }

    if (   !$has_public_jars
        && !$self->processable->is_transitional
        && $self->processable->name =~ /^lib[^\s,]+-java$/){

        # Skip this if it installs a symlink in usr/share/java
        my $java_dir
          = $self->processable->installed->resolve_path('usr/share/java/');

        my $has_jars = 0;
        $has_jars = 1
          if $java_dir
          && (any { $_->name =~ m{^[^/]+\.jar$} } $java_dir->children);

        $self->hint('javalib-but-no-public-jars')
          unless $has_jars;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

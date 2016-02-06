# java -- lintian check script -*- perl -*-

# Copyright (C) 2011 Vincent Fourmond
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

package Lintian::java;
use strict;
use warnings;
use autodie;

use List::MoreUtils qw(any none);
use Lintian::Data ();

use Lintian::Tags qw(tag);
use Lintian::Util qw(normalize_pkg_path);

our $MAX_BYTECODE = Lintian::Data->new('java/constants', qr/\s*=\s*/o);

sub run {
    my ($pkg, undef, $info) = @_;
    my $java_info = $info->java_info;
    my $missing_jarwrapper = 0;
    my $need_cp = 0;
    my $has_public_jars = 0;
    my $has_jars = 0;
    my $jmajlow = '-';

    my $depends = $info->relation('strong')->unparse();
    # Remove all libX-java-doc packages to avoid thinking they are java libs
    #  - note the result may not be a valid dependency listing
    $depends =~ s/lib[^\s,]+-java-doc//go;

    my @java_lib_depends = ($depends =~ m/\b(lib[^\s,]+-java)\b/og);

    $need_cp = 1 if @java_lib_depends;

    # We first loop over jar files to find problems

    for my $jar_file (sort keys %{$java_info}) {
        my $files = $java_info->{$jar_file}{files};
        my $manifest = $java_info->{$jar_file}{manifest};
        my $operm = $info->index($jar_file)->operm;
        my $jar_dir;
        my $classes = 0;
        my $datafiles = 1;
        my $cp = '';
        my $bsname = '';

        if (exists $java_info->{$jar_file}{error}) {
            tag 'zip-parse-error', "$jar_file:",$java_info->{$jar_file}{error};
            next;
        }

        # The Java Policy says very little about requires for (jars in) JVMs
        next if $jar_file =~ m#usr/lib/jvm(?:-exports)?/[^/]++/#o;
        # Ignore Mozilla's jar files, see #635495
        next if $jar_file =~ m#usr/lib/xul(?:-ext|runner[^/]*+)/#o;

        $jar_dir = $jar_file;
        $jar_dir =~ s,[^/]+$,,o;
        $has_jars = 1;

        if($jar_file =~ m#^usr/share/java/[^/]+\.jar$#o) {
            $has_public_jars = 1;
        }
        # check for common code files like .class or .clj (Clojure files)
        foreach my $class (grep { m/\.(?:class|clj)$/oi } sort keys %{$files}){
            my $mver = $files->{$class};
            $classes = 1;
            next if $class =~ m/\.clj$/;
            # .class but no major version?
            next if $mver eq '-';
            if (   $mver <= $MAX_BYTECODE->value('min-bytecode-version') - 1
                or $mver
                > $MAX_BYTECODE->value('max-bytecode-existing-version')) {
                # First public major version was 45 (Java1), latest
                # version is 52 (Java8).
                tag 'unknown-java-class-version', $jar_file,
                  "($class -> $mver)";
                # Skip the rest of this Jar.
                last;
            }

            # Collect the "lowest" Class version used.  We assume that
            # mixed class formats implies special compat code for certain
            # JVM cases.
            if ($jmajlow eq '-') {
                # first;
                $jmajlow = $mver;
            } else {
                $jmajlow = $mver if $mver < $jmajlow;
            }
        }

        $datafiles = 0
          if none { m/\.(?:xml|properties|x?html|xhp)$/io } keys %$files;

        if($operm & 0111) {
            # Executable ?
            tag 'executable-jar-without-main-class', $jar_file
              unless $manifest && $manifest->{'Main-Class'};

            # Here, we need to check that the package depends on
            # jarwrapper.
            $missing_jarwrapper = 1
              unless $info->relation('strong')->implies('jarwrapper');
        } elsif ($jar_file !~ m#^usr/share/#) {
            tag 'jar-not-in-usr-share', $jar_file;
        }

        $cp = $manifest->{'Class-Path'}//'' if $manifest;
        $bsname = $manifest->{'Bundle-SymbolicName'}//'' if $manifest;

        if ($manifest) {
            if (!$classes) {

               # Eclipse / OSGi bundles are sometimes source bundles
               #   these do not ship classes but java files and other sources.
               # Javadoc jars deployed in the Maven repository also do not ship
               #   classes but HTML files, images and CSS files
                if ((
                           $bsname !~ m/\.source$/o
                        && $jar_file!~ m#^usr/share/maven-repo/.*-javadoc\.jar#
                        && $jar_file!~m#\.doc(?:\.(?:user|isv))?_[^/]+.jar#
                        && $jar_file!~m#\.source_[^/]+.jar#
                    )
                    || $cp
                  ) {
                    tag 'codeless-jar', $jar_file;
                }
            }
        } elsif ($classes) {
            tag 'missing-manifest', $jar_file;
        }

        if (!$cp) {
            # Do we have OSGi instead?
            $need_cp = 0 if $bsname;
            # Maybe it is a maven plugin?
            $need_cp = 0
              if $need_cp
              && any { m,^META-INF/maven/plugin.xml$,io } keys %$files;
        } else {
            # Only run the tests when a classpath is present
            my @relative;
            my @paths = split(m/\s++/o, $cp);
            $need_cp = 0;
            for my $p (@paths) {
                if ($p) {
                    # Strip leading ./
                    $p =~ s#^\./++##og;
                    if ($p !~ m#^(?:file://)?/#o and $p =~ m#/#o) {
                        my $target = normalize_pkg_path($jar_dir, $p);
                        my $tinfo;
                        # Can it be normalized?
                        next unless defined($target);
                        # Relative link to usr/share/java ? Works if
                        # we are depending of a Java library.
                        next
                          if $target =~ m,^usr/share/java/[^/]+.jar$,o
                          and @java_lib_depends;
                        $tinfo = $info->index($target);
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

            tag 'classpath-contains-relative-path',
              "$jar_file: " . join(', ', @relative)
              if @relative;
        }

        if (   $has_public_jars
            && $pkg =~ /^lib.*maven.*plugin.*/
            && $jar_file !~ m#^usr/share/maven-repo/.*\.jar#) {
            # Trigger a warning when a maven plugin lib is installed in
            # /usr/share/java/
            tag 'maven-plugin-in-usr-share-java', $jar_file;
        }

    }

    tag 'missing-dep-on-jarwrapper' if $missing_jarwrapper;

    if ($jmajlow ne '-') {
        # Byte code numbers:
        #  45-49 -> Java1 - Java5 (Always ok)
        #     50 -> Java6
        #     51 -> Java7
        #     52 -> Java8
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
            my $v = $jmajlow - 44;
            tag 'incompatible-java-bytecode-format',
              "Java${v} version (Class format: $jmajlow)";
        }
    }

    if ($has_jars && $need_cp && $pkg =~ /^lib[^\s,]+-java$/) {
        # Only tag if there is at least one jar file and one strong
        # java dependency and no classpath/osgi.  Technically there
        # should be no reason to have a strong relation with a java
        # library without having a jar file, but we ignore some jars
        # (e.g. in JVMs) so going safe here.
        tag 'missing-classpath', join(', ', @java_lib_depends);
    }

    if (!$has_public_jars && $pkg =~ /^lib[^\s,]+-java$/) {
        # Skip this if it installs a symlink in usr/share/java
        return if any { m@^usr/share/java/[^/]+\.jar$@o } $info->sorted_index;
        tag 'javalib-but-no-public-jars';
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

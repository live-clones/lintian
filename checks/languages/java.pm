# languages/java -- lintian check script -*- perl -*-

# Copyright © 2011 Vincent Fourmond
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

package Lintian::languages::java;

use v5.20;
use warnings;
use utf8;
use autodie;

use File::Basename;
use List::MoreUtils qw(any none);

use Lintian::Data ();
use Lintian::Util qw(normalize_pkg_path $PKGNAME_REGEX);

use Moo;
use namespace::clean;

with 'Lintian::Check';

our $CLASS_REGEX = qr/\.(?:class|cljc?)/;
our $MAX_BYTECODE = Lintian::Data->new('java/constants', qr/\s*=\s*/);

sub source {
    my ($self) = @_;

    for my $file ($self->processable->patched->sorted_list) {
        my $java_info = $file->java_info;
        next
          unless scalar keys %{$java_info};

        my $files = $java_info->{files};
        $self->tag('source-contains-prebuilt-java-object', $file)
          if any { m/$CLASS_REGEX$/i } keys %{$files}
          and $self->processable->name ne 'lintian';
    }

    return;
}

sub installable {
    my ($self) = @_;

    my $pkg = $self->package;
    my $type = $self->type;
    my $processable = $self->processable;

    my $missing_jarwrapper = 0;
    my $has_public_jars = 0;
    my $has_jars = 0;
    my $jmajlow = '-';

    my $depends = $processable->relation('strong')->unparse;
    # Remove all libX-java-doc packages to avoid thinking they are java libs
    #  - note the result may not be a valid dependency listing
    $depends =~ s/lib[^\s,]+-java-doc//g;

    my @java_lib_depends = ($depends =~ m/\b(lib[^\s,]+-java)\b/g);

    # We first loop over jar files to find problems

    for my $file ($processable->installed->sorted_list) {

        my $java_info = $file->java_info;
        next
          unless scalar keys %{$java_info};

        my $files = $java_info->{files};
        my $manifest = $java_info->{manifest};
        my $operm = $file->operm;
        my $jar_dir = dirname($file);
        my $classes = 0;
        my $datafiles = 1;
        my $cp = '';
        my $bsname = '';

        if (exists $java_info->{error}) {
            $self->tag('zip-parse-error', "$file:",$java_info->{error});
            next;
        }

        # The Java Policy says very little about requires for (jars in) JVMs
        next
          if $file->name =~ m#usr/lib/jvm(?:-exports)?/[^/]++/#o;

        # Ignore Mozilla's jar files, see #635495
        next
          if $file->name =~ m#usr/lib/xul(?:-ext|runner[^/]*+)/#o;

        $has_jars = 1;
        if($file->name =~ m#^usr/share/java/[^/]+\.jar$#o) {
            $has_public_jars = 1;
            $self->tag('bad-jar-name', $file)
              unless basename($file->name) =~ /^$PKGNAME_REGEX\.jar$/;
        }
        # check for common code files like .class or .clj (Clojure files)
        foreach my $class (grep { m/$CLASS_REGEX$/i } sort keys %{$files}){
            my $mver = $files->{$class};
            (my $src = $class) =~ s/\.[^.]+$/\.java/;
            $self->tag('jar-contains-source', $file, $src)
              if %{$files}{$src};
            $classes = 1;

            next
              if $class =~ m/\.cljc?$/;

            # .class but no major version?
            next
              if $mver eq '-';
            if (   $mver <= $MAX_BYTECODE->value('min-bytecode-version') - 1
                or $mver
                > $MAX_BYTECODE->value('max-bytecode-existing-version')) {
                # First public major version was 45 (Java1), latest
                # version is 55 (Java11).
                $self->tag('unknown-java-class-version', $file,
                    "($class -> $mver)");
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
          if none { m/\.(?:xml|properties|x?html|xhp)$/i } keys %$files;

        if($operm & 0111) {
            # Executable ?
            $self->tag('executable-jar-without-main-class', $file->name)
              unless $manifest && $manifest->{'Main-Class'};

            # Here, we need to check that the package depends on
            # jarwrapper.
            $missing_jarwrapper = 1
              unless $processable->relation('strong')->implies('jarwrapper');
        } elsif ($file->name !~ m#^usr/share/#) {
            $self->tag('jar-not-in-usr-share', $file->name);
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
                           $bsname !~ m/\.source$/
                        && $file->name
                        !~ m#^usr/share/maven-repo/.*-javadoc\.jar#
                        && $file->name!~m#\.doc(?:\.(?:user|isv))?_[^/]+.jar#
                        && $file->name!~m#\.source_[^/]+.jar#
                    )
                    || $cp
                ) {
                    $self->tag('codeless-jar', $file->name);
                }
            }
        } elsif ($classes) {
            $self->tag('missing-manifest', $file->name);
        }

        if ($cp) {
            # Only run the tests when a classpath is present
            my @relative;
            my @paths = split(m/\s++/, $cp);
            for my $p (@paths) {
                if ($p) {
                    # Strip leading ./
                    $p =~ s#^\./++##g;
                    if ($p !~ m#^(?:file://)?/# and $p =~ m#/#) {
                        my $target = normalize_pkg_path($jar_dir, $p);
                        my $tinfo;
                        # Can it be normalized?
                        next unless defined($target);
                        # Relative link to usr/share/java ? Works if
                        # we are depending of a Java library.
                        next
                          if $target =~ m,^usr/share/java/[^/]+.jar$,
                          and @java_lib_depends;
                        $tinfo = $processable->installed->lookup($target);
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

            $self->tag(
                'classpath-contains-relative-path',
                $file->name . ': ' . join(', ', @relative))if @relative;
        }

        if (   $has_public_jars
            && $pkg =~ /^lib.*maven.*plugin.*/
            && $file->name !~ m#^usr/share/maven-repo/.*\.jar#) {
            # Trigger a warning when a maven plugin lib is installed in
            # /usr/share/java/
            $self->tag('maven-plugin-in-usr-share-java', $file->name);
        }

    }

    $self->tag('missing-dep-on-jarwrapper') if $missing_jarwrapper;

    if ($jmajlow ne '-') {
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
            my $v = $jmajlow - 44;
            $self->tag(
                'incompatible-java-bytecode-format',
                "Java${v} version (Class format: $jmajlow)"
            );
        }
    }

    my $is_transitional = $processable->is_pkg_class('transitional');
    if (!$has_public_jars && !$is_transitional && $pkg =~ /^lib[^\s,]+-java$/){
        # Skip this if it installs a symlink in usr/share/java
        my $java_dir= $processable->installed->resolve_path('usr/share/java/');
        my $has_jars = 0;
        $has_jars = 1
          if $java_dir
          and any { $_->name =~ m@^[^/]+\.jar$@o } $java_dir->children;
        $self->tag('javalib-but-no-public-jars') if not $has_jars;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

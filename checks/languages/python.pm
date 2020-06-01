# languages/python -- lintian check script -*- perl -*-
#
# Copyright © 2016 Chris Lamb
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

package Lintian::languages::python;

use v5.20;
use warnings;
use utf8;
use autodie;

use List::MoreUtils qw(any none);

use Lintian::Relation qw(:constants);
use Lintian::Relation::Version qw(versions_lte);

use Moo;
use namespace::clean;

with 'Lintian::Check';

my @FIELDS = qw(Depends Pre-Depends Recommends Suggests);
my @IGNORE = qw(-dev$ -docs?$ -common$ -tools$);
my @PYTHON2 = qw(python python2.7 python-dev);
my @PYTHON3 = qw(python3 python3-dev);

my %DJANGO_PACKAGES = (
    '^python3-django-' => 'python3-django',
    '^python2?-django-' => 'python-django',
);

my %REQUIRED_DEPENDS = (
    'python2' =>
      'python-minimal:any | python:any | python2-minimal:any | python2:any',
    'python3' => 'python3-minimal:any | python3:any',
);

my %MISMATCHED_SUBSTVARS = (
    '^python3-.+' => '${python:Depends}',
    '^python2?-.+' => '${python3:Depends}',
);

my $ALLOWED_PYTHON_FILES = Lintian::Data->new('files/allowed-python-files');
my $GENERIC_PYTHON_MODULES= Lintian::Data->new('files/generic-python-modules');

my $VERSIONS = Lintian::Data->new('python/versions', qr/\s*=\s*/);
my @VERSION_FIELDS = qw(x-python-version xs-python-version x-python3-version);

sub source {
    my ($self) = @_;

    my $pkg = $self->package;
    my $processable = $self->processable;

    my @package_names = $processable->binaries;
    foreach my $bin (@package_names) {
        # Python 2 modules
        if ($bin =~ /^python2?-(.*)$/) {
            my $suffix = $1;
            next if any { $bin =~ /$_/ } @IGNORE;
            next if any { $_ eq "python3-${suffix}" } @package_names;
            # Don't trigger if we ship any Python 3 module
            next if any {
                $processable->binary_relation($_, 'all')
                  ->implies('${python3:Depends}')
            }
            @package_names;
            $self->tag('python-foo-but-no-python3-foo', $bin);
        }
    }

    my $build_all = $processable->relation('build-depends-all');
    $self->tag('build-depends-on-python-sphinx-only')
      if $build_all->implies('python-sphinx')
      and not $build_all->implies('python3-sphinx');

    $self->tag(
        'alternatively-build-depends-on-python-sphinx-and-python3-sphinx')
      if $processable->field('build-depends', '')
      =~ m,\bpython-sphinx\s+\|\s+python3-sphinx\b,g;

    # Mismatched substvars
    foreach my $regex (keys %MISMATCHED_SUBSTVARS) {
        my $substvar = $MISMATCHED_SUBSTVARS{$regex};
        for my $binpkg ($processable->binaries) {
            next if any { $binpkg =~ /$_/ } @IGNORE;
            next if $binpkg !~ qr/$regex/;
            $self->tag('mismatched-python-substvar', $binpkg, $substvar)
              if $processable->binary_relation($binpkg, 'all')
              ->implies($substvar);
        }
    }

    foreach my $field (@VERSION_FIELDS) {
        my $pyversion = $processable->source_field($field);
        next unless defined($pyversion);

        my @valid = (
            ['\d+\.\d+', '\d+\.\d+'],['\d+\.\d+'],
            ['\>=\s*\d+\.\d+', '\<\<\s*\d+\.\d+'],['\>=\s*\d+\.\d+'],
            ['current', '\>=\s*\d+\.\d+'],['current'],
            ['all']);

        my @pyversion = split(/\s*,\s*/, $pyversion);

        if ($pyversion =~ m/^current/) {
            $self->tag('python-version-current-is-deprecated', $field);
        }

        if (@pyversion > 2) {
            if (any { !/^\d+\.\d+$/ } @pyversion) {
                $self->tag('malformed-python-version', $field, $pyversion);
            }
        } else {
            my $okay = 0;
            for my $rule (@valid) {
                if (
                    $pyversion[0] =~ /^$rule->[0]$/
                    && ((
                               $pyversion[1]
                            && $rule->[1]
                            && $pyversion[1] =~ /^$rule->[1]$/
                        )
                        || (!$pyversion[1] && !$rule->[1]))
                ) {
                    $okay = 1;
                    last;
                }
            }
            $self->tag('malformed-python-version', $field, $pyversion)
              unless $okay;
        }

        if ($pyversion =~ /\b(([23])\.\d+)$/) {
            my ($v, $major) = ($1, $2);
            my $old = $VERSIONS->value("old-python$major");
            my $ancient = $VERSIONS->value("ancient-python$major");

            if (versions_lte($v, $ancient)) {
                $self->tag('ancient-python-version-field', $field, $v);
            } elsif (versions_lte($v, $old)) {
                $self->tag('old-python-version-field', $field, $v);
            }
        }
    }

    $self->tag('source-package-encodes-python-version')
      if $processable->name =~ m/^python\d-/
      and $processable->name ne 'python3-defaults';

    return;
}

sub installable {
    my ($self) = @_;

    my $pkg = $self->package;
    my $processable = $self->processable;

    my $deps = Lintian::Relation->and($processable->relation('all'),
        $processable->relation('provides'), $pkg);
    my @entries
      = $processable->changelog
      ? @{$processable->changelog->entries}
      : ();

    # Check for missing dependencies
    if ($pkg !~ /-dbg$/) {
        foreach my $file ($processable->installed->sorted_list) {
            if (    $file->is_file
                and $file
                =~ m,usr/lib/(?<version>python[23])[\d.]*/(?:site|dist)-packages,
                and not $deps->implies($REQUIRED_DEPENDS{$+{version}})) {
                $self->tag('python-package-missing-depends-on-python');
                last;
            }
        }
    }

    # Check for duplicate dependencies
    for my $field (@FIELDS) {
        my $dep = $processable->relation($field);
      FIELD: for my $py2 (@PYTHON2) {
            for my $py3 (@PYTHON3) {
                if ($dep->implies("$py2:any") and $dep->implies("$py3:any")) {
                    $self->tag('depends-on-python2-and-python3',
                        "$field: $py2, [..], $py3");
                    last FIELD;
                }
            }
        }
    }

    # Python 2 modules
    if (    $pkg =~ /^python2?-/
        and none { $pkg =~ /$_$/ } @IGNORE
        and @entries == 1
        and $entries[0]->Changes
        !~ /\bpython ?2(?:\.x)? (?:variant|version)\b/im
        and index($entries[0]->Changes, $pkg) == -1) {
        $self->tag('new-package-should-not-package-python2-module', $pkg);
    }

    # Python applications
    if ($pkg !~ /^python[23]?-/ and none { $_ eq $pkg } @PYTHON2) {
        for my $field (@FIELDS) {
            for my $dep (@PYTHON2) {
                $self->tag(
                    'dependency-on-python-version-marked-for-end-of-life',
                    "($field: $dep)")
                  if $processable->relation($field)->implies("$dep:any");
            }
        }
    }

    # Django modules
    foreach my $regex (keys %DJANGO_PACKAGES) {
        my $basepkg = $DJANGO_PACKAGES{$regex};
        next if $pkg !~ /$regex/;
        next if any { $pkg =~ /$_/ } @IGNORE;
        $self->tag('django-package-does-not-depend-on-django', $basepkg)
          if not $processable->relation('strong')->implies($basepkg);
    }

    if ($pkg =~ /^python([23]?)-/ and none { $pkg =~ /$_/ } @IGNORE) {
        my $version = $1 || '2'; # Assume python-foo is a Python 2.x package
        my @prefixes = ($version eq '2') ? 'python3' : ('python', 'python2');

        for my $field (@FIELDS) {
            for my $prefix (@prefixes) {
                my $visit = sub {
                    my $rel = $_;
                    return if any { $rel =~ /$_/ } @IGNORE;
                    $self->tag(
'python-package-depends-on-package-from-other-python-variant',
                        "$field: $rel"
                    ) if /^$prefix-/;
                };
                $processable->relation($field)->visit($visit, VISIT_PRED_NAME);
            }
        }
    }

    return;
}

sub files {
    my ($self, $file) = @_;

    # .pyc/.pyo (compiled Python files)
    #  skip any file installed inside a __pycache__ directory
    #  - we have a separate check for that directory.
    if ($file->name =~ m,\.py[co]$, && $file->name !~ m,/__pycache__/,) {
        $self->tag('package-installs-python-bytecode', $file->name);
    }

    # __pycache__ (directory for pyc/pyo files)
    if ($file->is_dir && $file->name =~ m,/__pycache__/,){
        $self->tag('package-installs-python-pycache-dir', $file);
    }

    if (   $file->is_file
        && $file->name
        =~ m,^usr/lib/debug/usr/lib/pyshared/(python\d?(?:\.\d+))/(.++)$,) {
        my $correct = "usr/lib/debug/usr/lib/pymodules/$1/$2";
        $self->tag('python-debug-in-wrong-location', $file->name, $correct);
    }

    # .egg (Python egg files)
    $self->tag('package-installs-python-egg', $file->name)
      if $file->name =~ m,\.egg$,
      && ( $file->name =~ m,^usr/lib/python\d+(?:\.\d+/),
        || $file->name =~ m,^usr/lib/pyshared,
        || $file->name =~ m,^usr/share/,);

    # /usr/lib/site-python
    $self->tag('file-in-usr-lib-site-python', $file->name)
      if $file->name =~ m,^usr/lib/site-python/\S,;

    # pythonX.Y extensions
    if (   $file->name =~ m,^usr/lib/python\d\.\d/\S,
        && $file->name !~ m,^usr/lib/python\d\.\d/(?:site|dist)-packages/,){

        $self->tag('third-party-package-in-python-dir', $file->name)
          unless $self->processable->source =~ m/^python(?:\d\.\d)?$/
          || $self->processable->source =~ m{\A python\d?-
                               (?:stdlib-extensions|profiler|old-doctools) \Z}xsm;
    }

    # ---------------- Python file locations
    #  - The Python people kindly provided the following table.
    # good:
    # /usr/lib/python2.5/site-packages/
    # /usr/lib/python2.6/dist-packages/
    # /usr/lib/python2.7/dist-packages/
    # /usr/lib/python3/dist-packages/
    #
    # bad:
    # /usr/lib/python2.5/dist-packages/
    # /usr/lib/python2.6/site-packages/
    # /usr/lib/python2.7/site-packages/
    # /usr/lib/python3.*/*-packages/
    if (
        $file->name =~ m{\A
                   (usr/lib/debug/)?
                   usr/lib/python (\d+(?:\.\d+)?)/
                   (site|dist)-packages/(.++)
                   \Z}oxsm
    ){
        my ($debug, $pyver, $loc, $rest) = ($1, $2, $3, $4);
        my ($pmaj, $pmin) = split(m/\./, $pyver, 2);
        my @correction;

        $pmin = 0
          unless (defined $pmin);

        $debug = ''
          unless (defined $debug);

        next
          if ($pmaj < 2 or $pmaj > 3); # Not Python 2 or 3

        if ($pmaj == 2 and $pmin < 6){
            # 2.4 and 2.5
            if ($loc ne 'site') {
                @correction = (
                    "${debug}usr/lib/python${pyver}/$loc-packages/$rest",
                    "${debug}usr/lib/python${pyver}/site-packages/$rest"
                );
            }
        } elsif ($pmaj == 3){
            # Python 3. Everything must be in python3/dist-... and
            # not python3.X/<something>
            if ($pyver ne '3' or $loc ne 'dist'){
                # bad mojo
                @correction = (
                    "${debug}usr/lib/python${pyver}/$loc-packages/$rest",
                    "${debug}usr/lib/python3/dist-packages/$rest"
                );
            }
        } else {
            # Python 2.6+
            if ($loc ne 'dist') {
                @correction = (
                    "${debug}usr/lib/python${pyver}/$loc-packages/$rest",
                    "${debug}usr/lib/python${pyver}/dist-packages/$rest"
                );
            }
        }

        $self->tag('python-module-in-wrong-location', @correction)
          if @correction;

        for my $regex ($GENERIC_PYTHON_MODULES->all) {
            $self->tag('python-module-has-overly-generic-name',
                $file->name, "($1)")
              if $rest =~ m,^($regex)(?:\.py|/__init__\.py)$,i;
        }

        $self->tag('unknown-file-in-python-module-directory', $file->name)
          if $file->is_file
          and $rest eq $file->basename  # "top-level"
          and not $ALLOWED_PYTHON_FILES->matches_any($file->basename, 'i');
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

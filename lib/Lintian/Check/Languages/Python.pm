# languages/python -- lintian check script -*- perl -*-
#
# Copyright (C) 2016 Chris Lamb
# Copyright (C) 2020 Louis-Philippe Veronneau <pollo@debian.org>
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Languages::Python;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any none);
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Relation;
use Lintian::Relation::Version qw(versions_lte);

const my $EMPTY => q{};
const my $ARROW => q{ -> };
const my $DOLLAR => q{$};

const my $PYTHON3_MAJOR => 3;
const my $PYTHON2_MIGRATION_MAJOR => 2;
const my $PYTHON2_MIGRATION_MINOR => 6;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my @FIELDS = qw(Depends Pre-Depends Recommends Suggests);
my @IGNORE = qw(-dev$ -docs?$ -common$ -tools$);
my @PYTHON2 = qw(python2:any python2.7:any python2-dev:any);
my @PYTHON3 = qw(python3:any python3-dev:any);

my %DJANGO_PACKAGES = (
    '^python3-django-' => 'python3-django',
    '^python2?-django-' => 'python-django',
);

my %REQUIRED_DEPENDS = (
    'python2' => 'python2-minimal:any | python2:any',
    'python3' => 'python3-minimal:any | python3:any',
);

my %MISMATCHED_SUBSTVARS = (
    '^python3-.+' => $DOLLAR . '{python:Depends}',
    '^python2?-.+' => $DOLLAR . '{python3:Depends}',
);

has ALLOWED_PYTHON_FILES => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->data->load('files/allowed-python-files');
    }
);
has GENERIC_PYTHON_MODULES => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->data->load('files/generic-python-modules');
    }
);

my @VERSION_FIELDS = qw(X-Python-Version XS-Python-Version X-Python3-Version);

has correct_location => (is => 'rw', default => sub { {} });

sub source {
    my ($self) = @_;

    my @installable_names = $self->processable->debian_control->installables;
    for my $installable_name (@installable_names) {
        # Python 2 modules
        if ($installable_name =~ /^python2?-(.*)$/) {
            my $suffix = $1;

            next
              if any { $installable_name =~ /$_/ } @IGNORE;

            next
              if any { $_ eq "python3-${suffix}" } @installable_names;

            # Don't trigger if we ship any Python 3 module
            next
              if any {
                $self->processable->binary_relation($_, 'all')
                  ->satisfies($DOLLAR . '{python3:Depends}')
              }@installable_names;

            $self->hint('python-foo-but-no-python3-foo', $installable_name);
        }
    }

    my $build_all = $self->processable->relation('Build-Depends-All');
    $self->hint('build-depends-on-python-sphinx-only')
      if $build_all->satisfies('python-sphinx')
      && !$build_all->satisfies('python3-sphinx');

    my $maintainer = $self->processable->fields->value('Maintainer');
    $self->hint('python-teams-merged', $maintainer)
      if $maintainer =~ m{python-modules-team\@lists\.alioth\.debian\.org}
      || $maintainer =~ m{python-apps-team\@lists\.alioth\.debian\.org};

    $self->hint(
        'alternatively-build-depends-on-python-sphinx-and-python3-sphinx')
      if $self->processable->fields->value('Build-Depends')
      =~ /\bpython-sphinx\s+\|\s+python3-sphinx\b/;

    my $debian_control = $self->processable->debian_control;

    # Mismatched substvars
    for my $regex (keys %MISMATCHED_SUBSTVARS) {
        my $substvar = $MISMATCHED_SUBSTVARS{$regex};

        for my $installable_name ($debian_control->installables) {

            next
              if any { $installable_name =~ /$_/ } @IGNORE;

            next
              if $installable_name !~ qr/$regex/;

            $self->hint('mismatched-python-substvar', $installable_name,
                $substvar)
              if $self->processable->binary_relation($installable_name, 'all')
              ->satisfies($substvar);
        }
    }

    my $VERSIONS = $self->data->load('python/versions', qr/\s*=\s*/);

    for my $field (@VERSION_FIELDS) {

        next
          unless $debian_control->source_fields->declares($field);

        my $pyversion= $debian_control->source_fields->value($field);

        my @valid = (
            ['\d+\.\d+', '\d+\.\d+'],['\d+\.\d+'],
            ['\>=\s*\d+\.\d+', '\<\<\s*\d+\.\d+'],['\>=\s*\d+\.\d+'],
            ['current', '\>=\s*\d+\.\d+'],['current'],
            ['all']
        );

        my @pyversion = split(/\s*,\s*/, $pyversion);

        if ($pyversion =~ m/^current/) {
            $self->hint('python-version-current-is-deprecated', $field);
        }

        if (@pyversion > 2) {
            if (any { !/^\d+\.\d+$/ } @pyversion) {
                $self->hint('malformed-python-version', $field, $pyversion);
            }
        } else {
            my $okay = 0;
            for my $rule (@valid) {
                if (
                    $pyversion[0] =~ /^$rule->[0]$/
                    && (
                        (
                            $pyversion[1]
                            && $rule->[1]
                            && $pyversion[1] =~ /^$rule->[1]$/
                        )
                        || (!$pyversion[1] && !$rule->[1])
                    )
                ) {
                    $okay = 1;
                    last;
                }
            }
            $self->hint('malformed-python-version', $field, $pyversion)
              unless $okay;
        }

        if ($pyversion =~ /\b(([23])\.\d+)$/) {
            my ($v, $major) = ($1, $2);
            my $old = $VERSIONS->value("old-python$major");
            my $ancient = $VERSIONS->value("ancient-python$major");

            if (versions_lte($v, $ancient)) {
                $self->hint('ancient-python-version-field', $field, $v);
            } elsif (versions_lte($v, $old)) {
                $self->hint('old-python-version-field', $field, $v);
            }
        }
    }

    $self->hint('source-package-encodes-python-version')
      if $self->processable->name =~ m/^python\d-/
      && $self->processable->name ne 'python3-defaults';

    my $build_depends = Lintian::Relation->new;
    $build_depends->load_norestriction(
        $self->processable->fields->value('Build-Depends'));

    my $pyproject= $self->processable->patched->resolve_path('pyproject.toml');
    if (defined $pyproject && $pyproject->is_open_ok) {

        my %PYPROJECT_PREREQUISITES = (
            'poetry.core.masonry.api' => 'python3-poetry-core:any',
            'flit_core.buildapi' => 'flit:any',
            'setuptools.build_meta' => 'python3-setuptools:any',
            'pdm.pep517.api' => 'python3-pdm-pep517:any'
        );

        open(my $fd, '<', $pyproject->unpacked_path)
          or die encode_utf8('Cannot open ' . $pyproject->unpacked_path);

        my $position = 1;
        while (my $line = <$fd>) {

            my $pointer = $pyproject->pointer($position);

            if ($line =~ m{^ \s* build-backend \s* = \s* "([^"]+)" }x) {

                my $backend = $1;

                $self->pointed_hint('uses-poetry-cli', $pointer)
                  if $backend eq 'poetry.core.masonry.api'
                  && $build_depends->satisfies('python3-poetry:any')
                  && !$build_depends->satisfies('python3-poetry-core:any');

                $self->pointed_hint('uses-pdm-cli', $pointer)
                  if $backend eq 'pdm.pep517.api'
                  && $build_depends->satisfies('python3-pdm:any')
                  && !$build_depends->satisfies('python3-pdm-pep517:any');

                if (exists $PYPROJECT_PREREQUISITES{$backend}) {

                    my $prerequisites = $PYPROJECT_PREREQUISITES{$backend}
                      . ', pybuild-plugin-pyproject:any';

                    $self->pointed_hint(
                        'missing-prerequisite-for-pyproject-backend',
                        $pointer, $backend,"(does not satisfy $prerequisites)")
                      if !$build_depends->satisfies($prerequisites);
                }
            }

        } continue {
            ++$position;
        }

        close $fd;
    }

    return;
}

sub visit_installed_files {
    my ($self, $item) = @_;

    # .pyc/.pyo (compiled Python files)
    #  skip any file installed inside a __pycache__ directory
    #  - we have a separate check for that directory.
    $self->pointed_hint('package-installs-python-bytecode', $item->pointer)
      if $item->name =~ /\.py[co]$/
      && $item->name !~ m{/__pycache__/};

    # __pycache__ (directory for pyc/pyo files)
    $self->pointed_hint('package-installs-python-pycache-dir', $item->pointer)
      if $item->is_dir
      && $item->name =~ m{/__pycache__/};

    if (   $item->is_file
        && $item->name
        =~ m{^usr/lib/debug/usr/lib/pyshared/(python\d?(?:\.\d+))/(.+)$}) {

        my $correct = "usr/lib/debug/usr/lib/pymodules/$1/$2";
        $self->pointed_hint('python-debug-in-wrong-location',
            $item->pointer, "better: $correct");
    }

    # .egg (Python egg files)
    $self->pointed_hint('package-installs-python-egg', $item->pointer)
      if $item->name =~ /\.egg$/
      && ( $item->name =~ m{^usr/lib/python\d+(?:\.\d+/)}
        || $item->name =~ m{^usr/lib/pyshared}
        || $item->name =~ m{^usr/share/});

    # /usr/lib/site-python
    $self->pointed_hint('file-in-usr-lib-site-python', $item->pointer)
      if $item->name =~ m{^usr/lib/site-python/\S};

    # pythonX.Y extensions
    if (   $item->name =~ m{^usr/lib/python\d\.\d/\S}
        && $item->name !~ m{^usr/lib/python\d\.\d/(?:site|dist)-packages/}){

        $self->pointed_hint('third-party-package-in-python-dir',$item->pointer)
          unless $self->processable->source_name =~ m/^python(?:\d\.\d)?$/
          || $self->processable->source_name =~ m{\A python\d?-
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
        $item->name =~ m{\A
                   (usr/lib/debug/)?
                   usr/lib/python(\d+(?:\.\d+)?)/
                   ((?:site|dist)-packages)/(.+)
                   \Z}xsm
    ){
        my ($debug, $pyver, $actual_package_dir, $relative) = ($1, $2, $3, $4);
        $debug //= $EMPTY;

        my ($pmaj, $pmin) = split(m{\.}, $pyver, 2);
        $pmin //= 0;

        next
          if $pmaj < $PYTHON2_MIGRATION_MAJOR;

        my ($module_name) = ($relative =~ m{^([^/]+)});

        my $actual_python_libpath = "usr/lib/python$pyver/";
        my $specified_python_libpath = "usr/lib/python$pmaj/";

        # for python 2.X, folder was python2.X and not python2
        $specified_python_libpath = $actual_python_libpath
          if $pmaj < $PYTHON3_MAJOR;

        my $specified_package_dir = 'dist-packages';

        # python 2.4 and 2.5
        $specified_package_dir = 'site-packages'
          if $pmaj == $PYTHON2_MIGRATION_MAJOR
          && $pmin < $PYTHON2_MIGRATION_MINOR;

        my $actual_module_path
          = $debug. $actual_python_libpath. "$actual_package_dir/$module_name";
        my $specified_module_path
          = $debug
          . $specified_python_libpath
          . "$specified_package_dir/$module_name";

        $self->correct_location->{$actual_module_path} = $specified_module_path
          unless $actual_module_path eq $specified_module_path;

        for my $regex ($self->GENERIC_PYTHON_MODULES->all) {
            $self->pointed_hint('python-module-has-overly-generic-name',
                $item->pointer, "($1)")
              if $relative =~ m{^($regex)(?:\.py|/__init__\.py)$}i;
        }

        $self->pointed_hint('unknown-file-in-python-module-directory',
            $item->pointer)
          if $item->is_file
          && $relative eq $item->basename  # "top-level"
          &&!$self->ALLOWED_PYTHON_FILES->matches_any($item->basename, 'i');
    }

    return;
}

sub installable {
    my ($self) = @_;

    $self->hint(
        'python-module-in-wrong-location',
        $_ . $ARROW . $self->correct_location->{$_}
    )for keys %{$self->correct_location};

    my $deps
      = $self->processable->relation('all')
      ->logical_and($self->processable->relation('Provides'),
        $self->processable->name);

    my @entries
      = $self->processable->changelog
      ? @{$self->processable->changelog->entries}
      : ();

    # Check for missing dependencies
    if ($self->processable->name !~ /-dbg$/) {
        for my $item (@{$self->processable->installed->sorted_list}) {

            if (   $item->is_file
                && $item->name
                =~ m{^usr/lib/(?<version>python[23])[\d.]*/(?:site|dist)-packages}
                && !$deps->satisfies($REQUIRED_DEPENDS{$+{version}})) {

                $self->hint('python-package-missing-depends-on-python');

                last;
            }
        }
    }

    # Check for duplicate dependencies
    for my $field (@FIELDS) {
        my $dep = $self->processable->relation($field);
      FIELD: for my $py2 (@PYTHON2) {
            for my $py3 (@PYTHON3) {

                if ($dep->satisfies($py2) && $dep->satisfies($py3)) {
                    $self->hint('depends-on-python2-and-python3',
                        $field, "(satisfies $py2, $py3)");
                    last FIELD;
                }
            }
        }
    }

    my $pkg = $self->processable->name;

    # Python 2 modules
    $self->hint('new-package-should-not-package-python2-module',
        $self->processable->name)
      if $self->processable->name =~ / ^ python2? - /msx
      && (none { $pkg =~ m{ $_ }x } @IGNORE)
      && @entries == 1
      && $entries[0]->Changes
      !~ / \b python [ ]? 2 (?:[.]x)? [ ] (?:variant|version) \b /imsx
      && $entries[0]->Changes !~ / \Q$pkg\E /msx;

    # Python applications
    if ($self->processable->name !~ /^python[23]?-/
        && (none { $_ eq $self->processable->name } @PYTHON2)) {
        for my $field (@FIELDS) {
            for my $dep (@PYTHON2) {

                $self->hint(
                    'dependency-on-python-version-marked-for-end-of-life',
                    $field, "(satisfies $dep)")
                  if $self->processable->relation($field)->satisfies($dep);
            }
        }
    }

    # Django modules
    for my $regex (keys %DJANGO_PACKAGES) {
        my $basepkg = $DJANGO_PACKAGES{$regex};

        next
          if $self->processable->name !~ /$regex/;

        next
          if any { $self->processable->name =~ /$_/ } @IGNORE;

        $self->hint('django-package-does-not-depend-on-django', $basepkg)
          unless $self->processable->relation('strong')->satisfies($basepkg);
    }

    if (
        $self->processable->name =~ /^python([23]?)-/
        && (none { $self->processable->name =~ /$_/ } @IGNORE)
    ) {
        my $version = $1 || '2'; # Assume python-foo is a Python 2.x package
        my @prefixes = ($version eq '2') ? 'python3' : qw(python python2);

        for my $field (@FIELDS) {
            for my $prefix (@prefixes) {

                my $visit = sub {
                    my $rel = $_;
                    return if any { $rel =~ /$_/ } @IGNORE;
                    $self->hint(
'python-package-depends-on-package-from-other-python-variant',
                        "$field: $rel"
                    ) if /^$prefix-/;
                };

                $self->processable->relation($field)
                  ->visit($visit, Lintian::Relation::VISIT_PRED_NAME);
            }
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

# languages/python -- lintian check script -*- perl -*-
#
# Copyright © 2016 Chris Lamb
# Copyright © 2020 Louis-Philippe Véronneau <pollo@debian.org>
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

package Lintian::Check::Languages::Python;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any none);

use Lintian::Relation;
use Lintian::Relation::Version qw(versions_lte);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $ARROW => q{ -> };

const my $PYTHON3_MAJOR => 3;
const my $PYTHON2_MIGRATION_MAJOR => 2;
const my $PYTHON2_MIGRATION_MINOR => 6;

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
    '^python3-.+' => '${python:Depends}',
    '^python2?-.+' => '${python3:Depends}',
);

has ALLOWED_PYTHON_FILES => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('files/allowed-python-files');
    });
has GENERIC_PYTHON_MODULES => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('files/generic-python-modules');
    });

my @VERSION_FIELDS = qw(X-Python-Version XS-Python-Version X-Python3-Version);

has correct_location => (is => 'rw', default => sub { {} });

sub source {
    my ($self) = @_;

    my $pkg = $self->processable->name;
    my $processable = $self->processable;

    my @package_names = $processable->debian_control->installables;
    foreach my $bin (@package_names) {
        # Python 2 modules
        if ($bin =~ /^python2?-(.*)$/) {
            my $suffix = $1;
            next if any { $bin =~ /$_/ } @IGNORE;
            next if any { $_ eq "python3-${suffix}" } @package_names;
            # Don't trigger if we ship any Python 3 module
            next if any {
                $processable->binary_relation($_, 'all')
                  ->satisfies('${python3:Depends}')
            }
            @package_names;
            $self->hint('python-foo-but-no-python3-foo', $bin);
        }
    }

    my $build_all = $processable->relation('Build-Depends-All');
    $self->hint('build-depends-on-python-sphinx-only')
      if $build_all->satisfies('python-sphinx')
      and not $build_all->satisfies('python3-sphinx');

    my $maintainer = $self->processable->fields->value('Maintainer');
    $self->hint('python-teams-merged', $maintainer)
      if $maintainer =~ m{python-modules-team\@lists\.alioth\.debian\.org}
      || $maintainer =~ m{python-apps-team\@lists\.alioth\.debian\.org};

    $self->hint(
        'alternatively-build-depends-on-python-sphinx-and-python3-sphinx')
      if $processable->fields->value('Build-Depends')
      =~ /\bpython-sphinx\s+\|\s+python3-sphinx\b/;

    # Mismatched substvars
    foreach my $regex (keys %MISMATCHED_SUBSTVARS) {
        my $substvar = $MISMATCHED_SUBSTVARS{$regex};
        for my $binpkg ($processable->debian_control->installables) {
            next if any { $binpkg =~ /$_/ } @IGNORE;
            next if $binpkg !~ qr/$regex/;
            $self->hint('mismatched-python-substvar', $binpkg, $substvar)
              if $processable->binary_relation($binpkg, 'all')
              ->satisfies($substvar);
        }
    }

    my $VERSIONS = $self->profile->load_data('python/versions', qr/\s*=\s*/);

    foreach my $field (@VERSION_FIELDS) {

        next
          unless $processable->debian_control->source_fields->declares($field);

        my $pyversion
          = $processable->debian_control->source_fields->value($field);

        my @valid = (
            ['\d+\.\d+', '\d+\.\d+'],['\d+\.\d+'],
            ['\>=\s*\d+\.\d+', '\<\<\s*\d+\.\d+'],['\>=\s*\d+\.\d+'],
            ['current', '\>=\s*\d+\.\d+'],['current'],
            ['all']);

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
      if $processable->name =~ m/^python\d-/
      and $processable->name ne 'python3-defaults';

    return;
}

sub visit_installed_files {
    my ($self, $file) = @_;

    # .pyc/.pyo (compiled Python files)
    #  skip any file installed inside a __pycache__ directory
    #  - we have a separate check for that directory.
    $self->hint('package-installs-python-bytecode', $file->name)
      if $file->name =~ /\.py[co]$/
      && $file->name !~ m{/__pycache__/};

    # __pycache__ (directory for pyc/pyo files)
    $self->hint('package-installs-python-pycache-dir', $file)
      if $file->is_dir
      && $file->name =~ m{/__pycache__/};

    if (   $file->is_file
        && $file->name
        =~ m{^usr/lib/debug/usr/lib/pyshared/(python\d?(?:\.\d+))/(.+)$}) {

        my $correct = "usr/lib/debug/usr/lib/pymodules/$1/$2";
        $self->hint('python-debug-in-wrong-location', $file->name, $correct);
    }

    # .egg (Python egg files)
    $self->hint('package-installs-python-egg', $file->name)
      if $file->name =~ /\.egg$/
      && ( $file->name =~ m{^usr/lib/python\d+(?:\.\d+/)}
        || $file->name =~ m{^usr/lib/pyshared}
        || $file->name =~ m{^usr/share/});

    # /usr/lib/site-python
    $self->hint('file-in-usr-lib-site-python', $file->name)
      if $file->name =~ m{^usr/lib/site-python/\S};

    # pythonX.Y extensions
    if (   $file->name =~ m{^usr/lib/python\d\.\d/\S}
        && $file->name !~ m{^usr/lib/python\d\.\d/(?:site|dist)-packages/}){

        $self->hint('third-party-package-in-python-dir', $file->name)
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
        $file->name =~ m{\A
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
            $self->hint('python-module-has-overly-generic-name',
                $file->name, "($1)")
              if $relative =~ m{^($regex)(?:\.py|/__init__\.py)$}i;
        }

        $self->hint('unknown-file-in-python-module-directory', $file->name)
          if $file->is_file
          and $relative eq $file->basename  # "top-level"
          and
          not $self->ALLOWED_PYTHON_FILES->matches_any($file->basename, 'i');
    }

    return;
}

sub installable {
    my ($self) = @_;

    $self->hint(
        'python-module-in-wrong-location',
        $_ . $ARROW . $self->correct_location->{$_}
    )for keys %{$self->correct_location};

    my $pkg = $self->processable->name;
    my $processable = $self->processable;

    my $deps = $processable->relation('all')
      ->logical_and($processable->relation('Provides'), $pkg);

    my @entries
      = $processable->changelog
      ? @{$processable->changelog->entries}
      : ();

    # Check for missing dependencies
    if ($pkg !~ /-dbg$/) {
        for my $file (@{$processable->installed->sorted_list}) {
            if (   $file->is_file
                && $file
                =~ m{^usr/lib/(?<version>python[23])[\d.]*/(?:site|dist)-packages}
                && !$deps->satisfies($REQUIRED_DEPENDS{$+{version}})) {
                $self->hint('python-package-missing-depends-on-python');
                last;
            }
        }
    }

    # Check for duplicate dependencies
    for my $field (@FIELDS) {
        my $dep = $processable->relation($field);
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

    # Python 2 modules
    $self->hint('new-package-should-not-package-python2-module', $pkg)
      if $pkg =~ / ^ python2? - /msx
      && none { $pkg =~ / \Q$_\E$ /msx } @IGNORE
      && @entries == 1
      && $entries[0]->Changes
      !~ / \b python [ ]? 2 (?:[.]x)? [ ] (?:variant|version) \b /imsx
      && $entries[0]->Changes !~ / \Q$pkg\E /msx;

    # Python applications
    if ($pkg !~ /^python[23]?-/ and none { $_ eq $pkg } @PYTHON2) {
        for my $field (@FIELDS) {
            for my $dep (@PYTHON2) {

                $self->hint(
                    'dependency-on-python-version-marked-for-end-of-life',
                    $field, "(satisfies $dep)")
                  if $processable->relation($field)->satisfies($dep);
            }
        }
    }

    # Django modules
    foreach my $regex (keys %DJANGO_PACKAGES) {
        my $basepkg = $DJANGO_PACKAGES{$regex};
        next if $pkg !~ /$regex/;
        next if any { $pkg =~ /$_/ } @IGNORE;
        $self->hint('django-package-does-not-depend-on-django', $basepkg)
          if not $processable->relation('strong')->satisfies($basepkg);
    }

    if ($pkg =~ /^python([23]?)-/ and none { $pkg =~ /$_/ } @IGNORE) {
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
                $processable->relation($field)
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

# files/python -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
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

package Lintian::files::python;

use strict;
use warnings;
use autodie;

use Moo;

use Lintian::Data;

with('Lintian::Check');

my $ALLOWED_PYTHON_FILES = Lintian::Data->new('files/allowed-python-files');
my $GENERIC_PYTHON_MODULES= Lintian::Data->new('files/generic-python-modules');

sub files {
    my ($self, $file) = @_;

    # .pyc/.pyo (compiled Python files)
    #  skip any file installed inside a __pycache__ directory
    #  - we have a separate check for that directory.
    if ($file->name =~ m,\.py[co]$,o && $file->name !~ m,/__pycache__/,o) {
        $self->tag('package-installs-python-bytecode', $file->name);
    }

    # __pycache__ (directory for pyc/pyo files)
    if ($file->is_dir && $file->name =~ m,/__pycache__/,o){
        $self->tag('package-installs-python-pycache-dir', $file);
    }

    if (   $file->is_file
        && $file->name
        =~ m,^usr/lib/debug/usr/lib/pyshared/(python\d?(?:\.\d+))/(.++)$,o) {
        my $correct = "usr/lib/debug/usr/lib/pymodules/$1/$2";
        $self->tag('python-debug-in-wrong-location', $file->name, $correct);
    }

    # .egg (Python egg files)
    $self->tag('package-installs-python-egg', $file->name)
      if $file->name =~ m,\.egg$,o
      && ( $file->name =~ m,^usr/lib/python\d+(?:\.\d+/),o
        || $file->name =~ m,^usr/lib/pyshared,o
        || $file->name =~ m,^usr/share/,o);

    # /usr/lib/site-python
    $self->tag('file-in-usr-lib-site-python', $file->name)
      if $file->name =~ m,^usr/lib/site-python/\S,;

    # pythonX.Y extensions
    if (   $file->name =~ m,^usr/lib/python\d\.\d/\S,
        && $file->name !~ m,^usr/lib/python\d\.\d/(?:site|dist)-packages/,){

        $self->tag('third-party-package-in-python-dir', $file->name)
          unless $self->source =~ m/^python(?:\d\.\d)?$/
          || $self->source =~ m{\A python\d?-
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
        my ($pmaj, $pmin) = split(m/\./o, $pyver, 2);
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

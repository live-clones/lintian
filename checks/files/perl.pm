# files/perl -- lintian check script -*- perl -*-

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

package Lintian::files::perl;

use strict;
use warnings;
use autodie;

use Moo;

with('Lintian::Check');

has perl_sources_in_lib => (is => 'rwp', default => sub { [] });
has has_perl_binaries => (is => 'rwp', default => 0);

sub breakdown {
    my ($self) = @_;

    unless ($self->has_perl_binaries) {

        $self->tag('package-installs-nonbinary-perl-in-usr-lib-perl5', $_)
          for @{$self->perl_sources_in_lib};
    }

    $self->_set_perl_sources_in_lib([]);
    $self->_set_has_perl_binaries(0);

    return;
}

sub files {
    my ($self, $file) = @_;

    # perllocal.pod
    $self->tag('package-installs-perllocal-pod', $file->name)
      if $file->name =~ m,^usr/lib/perl.*/perllocal.pod$,;

    # .packlist files
    if ($file->name =~ m,^usr/lib/perl.*/.packlist$,) {
        $self->tag('package-installs-packlist', $file->name);

    }elsif ($file->name =~ m,^usr/lib/(?:[^/]+/)?perl5/.*\.p[lm]$,) {
        push @{$self->perl_sources_in_lib}, $file->name;

    }elsif ($file->name =~ m,^usr/lib/(?:[^/]+/)?perl5/.*\.(?:bs|so)$,) {
        $self->_set_has_perl_binaries(1);
    }

    # perl modules
    if ($file->name =~ m,^usr/(?:share|lib)/perl/\S,) {

        # check if it's the "perl" package itself
        $self->tag('perl-module-in-core-directory', $file)
          unless $self->source eq 'perl';
    }

    # perl modules using old libraries
    # we do the same check on perl scripts in checks/scripts
    my $dep = $self->info->relation('strong');
    if (   $file->is_file
        && $file->name =~ m,\.pm$,
        && !$dep->implies('libperl4-corelibs-perl | perl (<< 5.12.3-7)')) {

        my $fd = $file->open;
        while (<$fd>) {
            if (
                m{ (?:do|require)\s+['"] # do/require

                   # Huge list of perl4 modules...
                   (abbrev|assert|bigfloat|bigint|bigrat
                   |cacheout|complete|ctime|dotsh|exceptions
                   |fastcwd|find|finddepth|flush|getcwd|getopt
                   |getopts|hostname|importenv|look|newgetopt
                   |open2|open3|pwd|shellwords|stat|syslog
                   |tainted|termcap|timelocal|validate)
                   # ... so they end with ".pl" rather than ".pm"
                   \.pl['"]
             }xsm
            ) {
                $self->tag('perl-module-uses-perl4-libs-without-dep',
                    "$file:$. ${1}.pl");
            }
        }
        close($fd);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

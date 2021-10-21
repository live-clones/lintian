# languages/perl -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
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

package Lintian::Check::Languages::Perl;

use v5.20;
use warnings;
use utf8;

use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

has perl_sources_in_lib => (is => 'rw', default => sub { [] });
has has_perl_binaries => (is => 'rw', default => 0);

sub visit_installed_files {
    my ($self, $file) = @_;

    # perllocal.pod
    $self->hint('package-installs-perllocal-pod', $file->name)
      if $file->name =~ m{^usr/lib/perl.*/perllocal.pod$};

    # .packlist files
    if ($file->name =~ m{^usr/lib/perl.*/.packlist$}) {
        $self->hint('package-installs-packlist', $file->name);

    }elsif ($file->name =~ m{^usr/lib/(?:[^/]+/)?perl5/.*\.p[lm]$}) {
        push @{$self->perl_sources_in_lib}, $file->name;

    }elsif ($file->name =~ m{^usr/lib/(?:[^/]+/)?perl5/.*\.(?:bs|so)$}) {
        $self->has_perl_binaries(1);
    }

    # perl modules
    if ($file->name =~ m{^usr/(?:share|lib)/perl/\S}) {

        # check if it's the "perl" package itself
        $self->hint('perl-module-in-core-directory', $file)
          unless $self->processable->source_name eq 'perl';
    }

    # perl modules using old libraries
    # we do the same check on perl scripts in checks/scripts
    my $dep = $self->processable->relation('strong');
    if (   $file->is_file
        && $file->name =~ /\.pm$/
        && !$dep->satisfies('libperl4-corelibs-perl | perl (<< 5.12.3-7)')) {

        open(my $fd, '<', $file->unpacked_path)
          or die encode_utf8('Cannot open ' . $file->unpacked_path);

        while (my $line = <$fd>) {
            if (
                $line =~ m{ (?:do|require)\s+['"] # do/require

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
                $self->hint('perl-module-uses-perl4-libs-without-dep',
                    "$file:$. ${1}.pl");
            }
        }
        close($fd);
    }

    return;
}

sub installable {
    my ($self) = @_;

    unless ($self->has_perl_binaries) {

        $self->hint('package-installs-nonbinary-perl-in-usr-lib-perl5', $_)
          for @{$self->perl_sources_in_lib};
    }

    $self->perl_sources_in_lib([]);
    $self->has_perl_binaries(0);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

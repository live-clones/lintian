# languages/perl/perl4/prerequisites -- lintian check script -*- perl -*-
#
# Copyright © 1998 Richard Braakman
# Copyright © 2002 Josip Rodin
# Copyright © 2016-2019 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Languages::Perl::Perl4::Prerequisites;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Basename;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $COLON => q{:};
const my $LEFT_SQUARE_BRACKET => q{[};
const my $RIGHT_SQUARE_BRACKET => q{]};

# check for obsolete perl libraries
const my $PERL4_PREREQUISITES => 'libperl4-corelibs-perl | perl (<< 5.12.3-7)';

has satisfies_perl4_prerequisites => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->processable->relation('strong')
          ->satisfies($PERL4_PREREQUISITES);
    });

sub visit_installed_files {
    my ($self, $item) = @_;

    # Consider /usr/src/ scripts as "documentation"
    # - packages containing /usr/src/ tend to be "-source" .debs
    #   and usually come with overrides
    # no checks necessary at all for scripts in /usr/share/doc/
    # unless they are examples
    return
      if ($item->name =~ m{^usr/share/doc/} || $item->name =~ m{^usr/src/})
      && $item->name !~ m{^usr/share/doc/[^/]+/examples/};

    return
      unless length $item->interpreter;

    my $basename = basename($item->interpreter);
    return
      unless $basename eq 'perl';

    return
      unless $item->is_open_ok;

    open(my $fd, '<', $item->unpacked_path)
      or die encode_utf8('Cannot open ' . $item->unpacked_path);

    my $position = 1;
    while (my $line = <$fd>) {
        if (
            $line =~m{ (?:do|require)\s+['"] # do/require

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

            my $module = "$1.pl";

            $self->hint(
                'script-uses-perl4-libs-without-dep',
                $module,
                $LEFT_SQUARE_BRACKET
                  . $item->name
                  . $COLON
                  . $position
                  . $RIGHT_SQUARE_BRACKET,
                "(does not satisfy $PERL4_PREREQUISITES)"
            )unless $self->satisfies_perl4_prerequisites;

        }

    } continue {
        ++$position;
    }

    close $fd;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

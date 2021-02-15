# files/licenses -- lintian check script -*- perl -*-

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

package Lintian::Check::Files::Licenses;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $file) = @_;

    # license files
    if (
        $file->basename =~ m{ \A
                # Look for commonly used names for license files
                (?: copying | licen[cs]e | l?gpl | bsd | artistic )
                # ... possibly followed by a version
                [v0-9._-]*
                (?:\. .* )? \Z
                }xsmi
        # Ignore some common extensions for source or compiled
        # extension files.  There was at least one file named
        # "license.el".  These are probably license-displaying
        # code, not license files.  Also ignore executable files
        # in general. This means we get false-negatives for
        # licenses files marked executable, but these will trigger
        # a warning about being executable. (See #608866)
        #
        # Another exception is made for .html and .php because
        # preserving working links is more important than saving
        # some bytes, and because a package had an HTML form for
        # licenses called like that.  Another exception is made
        # for various picture formats since those are likely to
        # just be simply pictures.
        #
        # DTD files are excluded at the request of the Mozilla
        # suite maintainers.  Zope products include license files
        # for runtime display.  underXXXlicense.docbook files are
        # from KDE.
        #
        # Ignore extra license files in examples, since various
        # package building software includes example packages with
        # licenses.
        && !$file->is_executable
        && $file->name !~ m{ \. (?:
                  # Common "non-license" file extensions...
                   el|[ch]|cc|p[ylmc]|[hu]i|p_hi|html|php|rb|xpm
                     |png|jpe?g|gif|svg|dtd|mk|lisp|yml|rs|ogg|xbm
               ) \Z}xsm
        && $file->name !~ m{^usr/share/zope/Products/.*\.(?:dtml|pt|cpt)$}
        && $file->name !~ m{/under\S+License\.docbook$}
        && $file->name !~ m{^usr/share/doc/[^/]+/examples/}
        # liblicense has a manpage called license
        && $file->name !~ m{^usr/share/man/(?:[^/]+/)?man\d/}
        # liblicense (again)
        && $file->name !~ m{^usr/share/pyshared-data/}
        # Rust crate unmodified upstream sources
        && $file->name !~ m{^usr/share/cargo/registry/}
        # Some GNOME/GTK software uses these to show the "license
        # header".
        && $file->name !~ m{
               ^usr/share/(?:gnome/)?help/[^/]+/[^/]+/license\.page$
             }x
        # base-files (which is required to ship them)
        && $file->name !~ m{^usr/share/common-licenses/[^/]+$}
        && !length($file->link)
        # Sphinx includes various license files
        && $file->name !~ m{/_sources/license(?:\.rst)?\.txt$}i
    ) {

        # okay, we cannot rule it out based on file name; but if
        # it is an elf or a static library, we also skip it.  (In
        # case you hadn't guessed; liblicense)
        my $fileinfo = $file->file_info;

        $self->hint('extra-license-file', $file->name)
          unless $fileinfo and ($fileinfo =~ m/^[^,]*\bELF\b/)
          or ($fileinfo =~ m/\bcurrent ar archive\b/);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

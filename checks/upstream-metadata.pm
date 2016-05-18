# upstream-metadata -- lintian check script -*- perl -*-

# Copyright © 2016 Petter Reinholdtsen
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

package Lintian::upstream_metadata;

use strict;
use warnings;

use Lintian::Tags qw(tag);

use YAML::XS;

sub run {
    my (undef, undef, $info) = @_;
    my $yamlfile = $info->index_resolved_path('debian/upstream/metadata');
    return if not $yamlfile;

    if ($yamlfile->is_open_ok) {
        my $yaml;
        eval { $yaml = YAML::XS::LoadFile($yamlfile->fs_path); };
        if (!$yaml) {
            my $msg;
            if (my ($reason, $doc, $line, $col)
                = $@
                =~ m/\AYAML::XS::Load Error: The problem:\n\n ++(.+)\n\nwas found at document: (\d+), line: (\d+), column: (\d+)\n/
              ) {
                $msg = "$reason (at document $doc, line $line, column $col)";
            }
            tag('upstream-metadata-yaml-invalid', $msg);
        }
    } else {
        tag('upstream-metadata-is-not-a-file');
    }
    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

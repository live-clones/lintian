# phppear -- lintian check script -*- perl -*-

# Copyright (C) 2013 Mathieu Parent <math.parent@gmail.com>
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

package Lintian::phppear;

use strict;
use warnings;

use Lintian::Tags qw(tag);
use Lintian::Relation;

sub run {
    my ($pkg, $type, $info) = @_;

    # PEAR or PECL package
    my $package_xml = $info->index('package.xml');
    my $package2_xml = $info->index('package2.xml');
    my $bdepends = $info->relation('build-depends');
    if (defined($package_xml) || defined($package2_xml)) {
        # Checking source builddep
        if (!$bdepends->implies('pkg-php-tools')) {
            tag 'pear-package-without-pkg-php-tools-builddep';
        } else {
            # Checking first binary relations
            my @binaries = $info->binaries;
            my $binary = $binaries[0];
            my $depends = $info->binary_relation($binary, 'depends');
            my $recommends = $info->binary_relation($binary, 'recommends');
            my $breaks = $info->binary_relation($binary, 'breaks');
            if (!$depends->implies('${phppear:Debian-Depends}')) {
                tag 'pear-package-but-missing-dependency', 'Depends';
            }
            if (!$recommends->implies('${phppear:Debian-Recommends}')) {
                tag 'pear-package-but-missing-dependency', 'Recommends';
            }
            if (!$breaks->implies('${phppear:Debian-Breaks}')) {
                tag 'pear-package-but-missing-dependency', 'Breaks';
            }
            # Checking overrides
            my $overrides = $info->debfiles('pkg-php-tools-overrides');
            if (-f $overrides) {
                if (!$bdepends->implies('pkg-php-tools (>= 1~)')) {
                    tag 'pear-package-feature-requires-newer-pkg-php-tools',
                        '(>= 1~)', 'for package name overrides';
                }
            }
        }
    }
    # PEAR channel
    my $channel_xml = $info->index('channel.xml');
    if (defined($channel_xml)) {
        if (!$bdepends->implies('pkg-php-tools')) {
            tag 'pear-channel-without-pkg-php-tools-builddep';
        }
    }
    return;
}

1;

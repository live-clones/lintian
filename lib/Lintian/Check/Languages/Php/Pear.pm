# langauges/php/pear -- lintian check script -*- perl -*-

# Copyright © 2013 Mathieu Parent <math.parent@gmail.com>
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

package Lintian::Check::Languages::Php::Pear;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(none);
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $pkg = $self->processable->name;
    my $type = $self->processable->type;
    my $processable = $self->processable;

    # Don't check package if it doesn't contain a .php file
    if (
        none { $_->basename =~ m/\.php$/i && !$_->is_dir }
        @{$processable->patched->sorted_list}
    ){
        return;
    }

    my $bdepends = $processable->relation('Build-Depends');
    my $package_type = 'unknown';

    # PEAR or PECL package
    my $package_xml = $processable->patched->lookup('package.xml');
    my $package2_xml = $processable->patched->lookup('package2.xml');
    if (defined($package_xml) || defined($package2_xml)) {
        # Checking source builddep
        if (!$bdepends->satisfies('pkg-php-tools')) {
            $self->hint('pear-package-without-pkg-php-tools-builddep');
        } else {
            # Checking first binary relations
            my @binaries = $processable->debian_control->installables;
            my $binary = $binaries[0];
            my $depends = $processable->binary_relation($binary, 'Depends');
            my $recommends
              = $processable->binary_relation($binary, 'Recommends');
            my $breaks = $processable->binary_relation($binary, 'Breaks');
            if (!$depends->satisfies('${phppear:Debian-Depends}')) {
                $self->hint('pear-package-but-missing-dependency', 'Depends');
            }
            if (!$recommends->satisfies('${phppear:Debian-Recommends}')) {
                $self->hint('pear-package-but-missing-dependency',
                    'Recommends');
            }
            if (!$breaks->satisfies('${phppear:Debian-Breaks}')) {
                $self->hint('pear-package-but-missing-dependency', 'Breaks');
            }

            # checking description
            my $description
              = $processable->debian_control->installable_fields($binary)
              ->untrimmed_value('Description');

            if ($description !~ /\$\{phppear:summary\}/) {
                $self->hint('pear-package-not-using-substvar',
                    '${phppear:summary}');
            }

            if ($description !~ /\$\{phppear:description\}/) {
                $self->hint('pear-package-not-using-substvar',
                    '${phppear:description}');
            }

            if (defined($package_xml) && $package_xml->is_regular_file) {

                # Wild guess package type as in
                # PEAR_PackageFile_v2::getPackageType()
                open(my $package_xml_fd, '<', $package_xml->unpacked_path)
                  or die encode_utf8(
                    'Cannot open ' . $package_xml->unpacked_path);

                while (my $line = <$package_xml_fd>) {
                    if (
                        $line =~ m{\A \s* <
                           (php|extsrc|extbin|zendextsrc|zendextbin)
                           release \s* /? > }xsm
                    ) {
                        $package_type = $1;
                        last;
                    }
                    if ($line =~ /^\s*<bundle\s*\/?>/){
                        $package_type = 'bundle';
                        last;
                    }
                }

                close $package_xml_fd;

                if ($package_type eq 'extsrc') { # PECL package
                    if (!$bdepends->satisfies('php-dev')) {
                        $self->hint('pecl-package-requires-build-dependency',
                            'php-dev');
                    }
                    if (!$bdepends->satisfies('dh-php')) {
                        $self->hint('pecl-package-requires-build-dependency',
                            'dh-php');
                    }
                }
            }
        }
    }
    # PEAR channel
    my $channel_xml = $processable->patched->lookup('channel.xml');
    if (defined($channel_xml)) {
        if (!$bdepends->satisfies('pkg-php-tools')) {
            $self->hint('pear-channel-without-pkg-php-tools-builddep');
        }
    }
    # Composer package
    my $composer_json = $processable->patched->lookup('composer.json');
    if (   !defined($package_xml)
        && !defined($package2_xml)
        && defined($composer_json)) {
        if (!$bdepends->satisfies('pkg-php-tools')) {
            $self->hint('composer-package-without-pkg-php-tools-builddep');
        }
    }
    # Check rules
    if (
        $bdepends->satisfies('pkg-php-tools')
        && (   defined($package_xml)
            || defined($package2_xml)
            || defined($channel_xml)
            || defined($composer_json))
    ) {
        my $rules = $processable->patched->resolve_path('debian/rules');
        if ($rules and $rules->is_open_ok) {
            my $has_buildsystem_phppear = 0;
            my $has_addon_phppear = 0;
            my $has_addon_phpcomposer= 0;
            my $has_addon_php = 0;

            open(my $rules_fd, '<', $rules->unpacked_path)
              or die encode_utf8('Cannot open ' . $rules->unpacked_path);

            while (my $line = <$rules_fd>) {

                while ($line =~ s/\\$// && defined(my $cont = <$rules_fd>)) {
                    $line .= $cont;
                }

                next
                  if $line =~ /^\s*\#/;

                $has_buildsystem_phppear = 1
                  if $line
                  =~ /^\t\s*dh\s.*--buildsystem(?:=|\s+)(?:\S+,)*phppear(?:,\S+)*\s/;

                $has_addon_phppear = 1
                  if $line
                  =~ /^\t\s*dh\s.*--with(?:=|\s+)(?:\S+,)*phppear(?:,\S+)*\s/;

                $has_addon_phpcomposer = 1
                  if $line
                  =~ /^\t\s*dh\s.*--with(?:=|\s+)(?:\S+,)*phpcomposer(?:,\S+)*\s/;

                $has_addon_php = 1
                  if $line
                  =~ /^\t\s*dh\s.*--with(?:=|\s+)(?:\S+,)*php(?:,\S+)*\s/;
            }

            close($rules_fd);

            if (   defined($package_xml)
                || defined($package2_xml)
                || defined($channel_xml)) {
                if (!$has_buildsystem_phppear) {
                    $self->hint('missing-pkg-php-tools-buildsystem','phppear');
                }
                if (!$has_addon_phppear) {
                    $self->hint('missing-pkg-php-tools-addon', 'phppear');
                }
                if (($package_type eq 'extsrc') and not $has_addon_php) {
                    $self->hint('missing-pkg-php-tools-addon', 'php');
                }
            }
            if (   !defined($package_xml)
                && !defined($package2_xml)
                && defined($composer_json)) {
                if (!$has_addon_phpcomposer) {
                    $self->hint('missing-pkg-php-tools-addon', 'phpcomposer');
                }
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

# languages/php/embedded -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
# Copyright (C) 2020 Felix Lechner
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

package Lintian::Check::Languages::Php::Embedded;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $PHP_EXT = qr{(?i)\.(?:php|inc|dtd)$};
my %PHP_FILES = (
    'libphp-adodb'         => qr{(?i)/adodb\.inc\.php$},
    'smarty3?'             => qr{(?i)/Smarty(?:_Compiler)?\.class\.php$},
    'libphp-phpmailer'     =>
      qr{(?i)/(phpmailer\.lang-(.*)\.php|PHPMailer\.php)$},
    'phpsysinfo'           =>
qr{(?i)/phpsysinfo\.dtd|/class\.(?:Linux|(?:Open|Net|Free|)BSD)\.inc\.php$},
    'libphp-snoopy'        => qr{(?i)/Snoopy\.class\.(?:php|inc)$},
    'php-geshi'            => qr{(?i)/geshi\.php$},
    'libphp-phplayersmenu' => qr{(?i)/.*layersmenu.*/(lib/)?PHPLIB\.php$},
    'libphp-phpsniff'      => qr{(?i)/phpSniff\.(?:class|core)\.php$},
    'libphp-jabber'        => qr{(?i)/(?:class\.)?jabber\.php$},
    'libphp-simplepie'     =>
      qr{(?i)/(?:class[\.-])?simplepie(?:\.(?:php|inc))+$},
    'libphp-jpgraph'       => qr{(?i)/jpgraph\.php$},
    'php-fpdf'             => qr{(?i)/fpdf\.php$},
    'php-tcpdf'            => qr{(?)/tcpdf\.php$},
    'php-dompdf'           => qr{(?)/Dompdf\.php$},
    'php-getid3'           => qr{(?)/(getid3(?:\.lib)?\.php|GetID3\.php)$},
    'php-php-gettext'      => qr{(?)/gettext\.inc$},
    'php-sparkline'        => qr{(?i)/Sparkline\.php$},
    'php-econea-nusoap'    => qr{(?i)/(?:class\.)?nusoap\.(?:php|inc)$},
    'php-htmlpurifier'     => qr{(?i)/HTMLPurifier\.php$},
);

# Cheap pre-filter: every pattern above ends in ".php", ".inc" or ".dtd".
my $PHP_INTERESTING = qr{\.(?:php|inc|dtd)}i;

my @PHP_PROVIDERS = map { [$_, qr{^$_$}, qr{$PHP_FILES{$_}}] } keys %PHP_FILES;

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    my $name = $item->name;

    return
      unless $name =~ $PHP_INTERESTING;

    my $package = $self->processable->name;

    # embedded PHP
    for my $entry (@PHP_PROVIDERS) {

        my ($provider, $package_regex, $file_regex) = @{$entry};

        next
          if $package =~ $package_regex;

        next
          unless $name =~ $file_regex;

        $self->pointed_hint('embedded-php-library', $item->pointer,
            'please use',$provider);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

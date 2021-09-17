# languages/php/embedded -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2020 Felix Lechner
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
    'libphp-phpmailer'     => qr{(?i)/class\.phpmailer(\.(?:php|inc))+$},
    'phpsysinfo'           =>
qr{(?i)/phpsysinfo\.dtd|/class\.(?:Linux|(?:Open|Net|Free|)BSD)\.inc\.php$},
    'php-openid'           => qr{/Auth/(?:OpenID|Yadis/Yadis)\.php$},
    'libphp-snoopy'        => qr{(?i)/Snoopy\.class\.(?:php|inc)$},
    'php-markdown'         => qr{(?i)/markdown\.php$},
    'php-geshi'            => qr{(?i)/geshi\.php$},
    'libphp-pclzip'        =>qr{(?i)/(?:class[.-])?pclzip\.(?:inc|lib)?\.php$},
    'libphp-phplayersmenu' => qr{(?i)/.*layersmenu.*/(lib/)?PHPLIB\.php$},
    'libphp-phpsniff'      => qr{(?i)/phpSniff\.(?:class|core)\.php$},
    'libphp-jabber'        => qr{(?i)/(?:class\.)?jabber\.php$},
    'libphp-simplepie'     =>
      qr{(?i)/(?:class[\.-])?simplepie(?:\.(?:php|inc))+$},
    'libphp-jpgraph'       => qr{(?i)/jpgraph\.php$},
    'php-fpdf'             => qr{(?i)/fpdf\.php$},
    'php-getid3'           => qr{(?i)/getid3\.(?:lib\.)?(?:\.(?:php|inc))+$},
    'php-php-gettext'      => qr{(?i)/(?<!pomo/)streams\.php$},
    'libphp-magpierss'     => qr{(?i)/rss_parse\.(?:php|inc)$},
    'php-simpletest'       => qr{(?i)/unit_tester\.php$},
    'libsparkline-php'     => qr{(?i)/Sparkline\.php$},
    'libnusoap-php'        => qr{(?i)/(?:class\.)?nusoap\.(?:php|inc)$},
    'php-htmlpurifier'     => qr{(?i)/HTMLPurifier\.php$},
    # not yet available in unstable:,
    # 'libphp-ixr'         => qr{(?i)/IXR_Library(?:\.inc|\.php)+$},
    # 'libphp-kses'        => qr{(?i)/(?:class\.)?kses\.php$},
);

sub visit_installed_files {
    my ($self, $file) = @_;

    return
      unless $file->is_file;

    # embedded PHP
    for my $provider (keys %PHP_FILES) {

        next
          if $self->processable->name =~ /^$provider$/;

        next
          unless $file->name =~ /$PHP_FILES{$provider}/;

        $self->hint('embedded-php-library', $file->name, 'please use',
            $provider);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# languages/php/pear/embedded -- lintian check script -*- perl -*-

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

package Lintian::Check::Languages::Php::Pear::Embedded;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $PEAR_MAGIC = qr{pear[/.]};
my $PEAR_EXT = qr{(?i)\.php$};
my %PEAR_FILES = (
    'php-auth'            => qr{/Auth} . $PEAR_EXT,
    'php-auth-http'       => qr{/Auth/HTTP} . $PEAR_EXT,
    'php-benchmark'       => qr{/Benchmark/(?:Timer|Profiler|Iterate)}
      . $PEAR_EXT,
    'php-http'            => qr{(?<!/Auth)/HTTP} . $PEAR_EXT,
    'php-cache'           => qr{/Cache} . $PEAR_EXT,
    'php-cache-lite'      => qr{/Cache/Lite} . $PEAR_EXT,
    'php-compat'          => qr{/Compat} . $PEAR_EXT,
    'php-config'          => qr{/Config} . $PEAR_EXT,
    'php-crypt-cbc'       => qr{/CBC} . $PEAR_EXT,
    'php-date'            => qr{/Date} . $PEAR_EXT,
    'php-db'              => qr{(?<!/Container)/DB} . $PEAR_EXT,
    'php-file'            => qr{(?<!/Container)/File} . $PEAR_EXT,
    'php-log'             =>
      qr{(?:/Log/(?:file|error_log|null|syslog|sql\w*)|/Log)} . $PEAR_EXT,
    'php-mail'            => qr{/Mail} . $PEAR_EXT,
    'php-mail-mime'       => qr{(?i)/mime(Part)?} . $PEAR_EXT,
    'php-mail-mimedecode' => qr{/mimeDecode} . $PEAR_EXT,
    'php-net-ftp'         => qr{/FTP} . $PEAR_EXT,
    'php-net-imap'        => qr{(?<!/Container)/IMAP} . $PEAR_EXT,
    'php-net-ldap'        => qr{(?<!/Container)/LDAP} . $PEAR_EXT,
    'php-net-smtp'        => qr{/SMTP} . $PEAR_EXT,
    'php-net-socket'      => qr{(?<!/FTP)/Socket} . $PEAR_EXT,
);

sub visit_installed_files {
    my ($self, $file) = @_;

    return
      unless $file->is_file;

    # embedded PEAR
    for my $provider (keys %PEAR_FILES) {

        next
          if $self->processable->name =~ /^$provider$/;

        next
          unless $file->name =~ /$PEAR_FILES{$provider}/;

        next
          unless length $file->bytes_match($PEAR_MAGIC);

        $self->hint('embedded-pear-module', $file->name, 'please use',
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

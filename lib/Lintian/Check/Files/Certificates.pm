# files/certificates -- lintian check script -*- perl -*-

# Copyright (C) 2024 Andrius Merkys <merkys@debian.org>
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

package Lintian::Check::Files::Certificates;

use v5.20;
use warnings;
use utf8;

use Net::SSL::ExpireDate;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub _is_certificate_expired {
    my ($self, $item) = @_;

    return 0
      unless $item->name =~ m{\.(pem|crt|pkcs12)$};

    my $expire_date;
    eval {
        $expire_date = Net::SSL::ExpireDate->new(file => $item->unpacked_path);
    };
    return defined $expire_date && $expire_date->is_expired;
}

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    $self->pointed_hint('package-installs-expired-certificate-file',
        $item->pointer)
      if $self->_is_certificate_expired($item);

    return;
}

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    $self->pointed_hint('source-contains-expired-certificate-file',
        $item->pointer)
      if $self->_is_certificate_expired($item);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

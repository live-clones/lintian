# files/pkgconfig -- lintian check script -*- perl -*-

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

package Lintian::Check::Files::Pkgconfig;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::SlidingWindow;

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

has PKG_CONFIG_BAD_REGEX => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('files/pkg-config-bad-regex',
            qr/~~~~~/,sub { return  qr/$_[0]/xsm;});
    });

sub visit_installed_files {
    my ($self, $file) = @_;

    my $architecture = $self->processable->fields->value('Architecture');

    # arch-indep pkgconfig
    if (   $file->is_regular_file
        && $file->name=~ m{^usr/(lib(/[^/]+)?|share)/pkgconfig/[^/]+\.pc$}){

        my $prefix = $1;
        my $pkg_config_arch = $2 // $EMPTY;
        $pkg_config_arch =~ s{\A/}{}ms;

        $self->hint('pkg-config-unavailable-for-cross-compilation',$file->name)
          if $prefix eq 'lib';

        open(my $fd, '<:raw', $file->unpacked_path)
          or die encode_utf8('Cannot open ' . $file->unpacked_path);

        my $sfd = Lintian::SlidingWindow->new;
        $sfd->handle($fd);

      BLOCK:
        while (my $block = $sfd->readwindow) {
            # remove comment line
            $block =~ s/\#\V*//gsm;
            # remove continuation line
            $block =~ s/\\\n/ /gxsm;
            # check if pkgconfig file include path point to
            # arch specific dir

            my $DEB_HOST_MULTIARCH
              = $self->profile->architectures->deb_host_multiarch;
            for my $madir (values %{$DEB_HOST_MULTIARCH}) {

                next
                  if $pkg_config_arch eq $madir;

                if ($block =~ m{\W\Q$madir\E(\W|$)}xms) {

                    $self->hint('pkg-config-multi-arch-wrong-dir',
                        $file->name,
                        'full text contains architecture specific dir',$madir);

                    last;
                }
            }

            foreach my $taboo ($self->PKG_CONFIG_BAD_REGEX->all) {

                my $regex = $self->PKG_CONFIG_BAD_REGEX->value($taboo);

                while($block =~ m{$regex}xmsg) {
                    my $extra = $1 // $EMPTY;
                    $extra =~ s/\s+/ /g;

                    $self->hint('pkg-config-bad-directive', $file->name,
                        $extra);
                }
            }
        }
        close($fd);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

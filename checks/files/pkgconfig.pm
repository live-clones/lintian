# files/pkgconfig -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
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

package Lintian::files::pkgconfig;

use strict;
use warnings;
use autodie;

use Moo;

use Lintian::SlidingWindow;

with('Lintian::Check');

my $MULTIARCH_DIRS = Lintian::Data->new('common/multiarch-dirs', qr/\s++/);

my $PKG_CONFIG_BAD_REGEX
  = Lintian::Data->new('files/pkg-config-bad-regex',qr/~~~~~/,
    sub { return  qr/$_[0]/xsm;});

sub files {
    my ($self, $file) = @_;

    my $architecture = $self->info->field('architecture', '');

    # arch-indep pkgconfig
    if (   $file->is_regular_file
        && $file->name=~ m,^usr/(lib(/[^/]+)?|share)/pkgconfig/[^/]+\.pc$,){

        my $prefix = $1;
        my $pkg_config_arch = $2 // '';
        $pkg_config_arch =~ s,\A/,,ms;

        $self->tag('pkg-config-unavailable-for-cross-compilation', $file->name)
          if $prefix eq 'lib';

        my $fd = $file->open(':raw');
        my $sfd = Lintian::SlidingWindow->new($fd);

      BLOCK:
        while (my $block = $sfd->readwindow) {
            # remove comment line
            $block =~ s,\#\V*,,gsm;
            # remove continuation line
            $block =~ s,\\\n, ,gxsm;
            # check if pkgconfig file include path point to
            # arch specific dir

          MULTI_ARCH_DIR:
            foreach my $wildcard ($MULTIARCH_DIRS->all) {

                my $madir = $MULTIARCH_DIRS->value($wildcard);

                if ($pkg_config_arch eq $madir) {
                    next MULTI_ARCH_DIR;
                }

                if ($block =~ m{\W\Q$madir\E(\W|$)}xms) {

                    $self->tag('pkg-config-multi-arch-wrong-dir',
                        $file->name,
                        'full text contains architecture specific dir',$madir);

                    last MULTI_ARCH_DIR;
                }
            }

          PKG_CONFIG_TABOO:
            foreach my $taboo ($PKG_CONFIG_BAD_REGEX->all) {

                my $regex = $PKG_CONFIG_BAD_REGEX->value($taboo);

                while($block =~ m{$regex}xmsg) {
                    my $extra = $1 // '';
                    $extra =~ s/\s+/ /g;

                    $self->tag('pkg-config-bad-directive', $file->name,$extra);
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

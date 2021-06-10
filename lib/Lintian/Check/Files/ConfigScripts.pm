# files/config-scripts -- lintian check script -*- perl -*-

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

package Lintian::Check::Files::ConfigScripts;

use v5.20;
use warnings;
use utf8;

use Unicode::UTF8 qw(encode_utf8);

use Lintian::SlidingWindow;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_installed_files {
    my ($self, $file) = @_;

    my $architecture = $self->processable->fields->value('Architecture');
    my $multiarch = $self->processable->fields->value('Multi-Arch') || 'no';

    # check old style config scripts
    if (   $file->name =~ m{^usr/bin/}
        && $file->name =~ m/-config$/
        && $file->is_script
        && $file->is_regular_file) {

        # try to find some indication of
        # config file (read only one block)

        open(my $fd, '<:raw', $file->unpacked_path)
          or die encode_utf8('Cannot open ' . $file->unpacked_path);

        my $sfd = Lintian::SlidingWindow->new;
        $sfd->handle($fd);

        my $block = $sfd->readwindow;

        # some common stuff found in config file
        if (
            $block
            && (   $block =~ / flag /msx
                || $block =~ m{ /include/ }msx
                || $block =~ / pkg-config /msx)
        ) {

            $self->hint('old-style-config-script', $file->name);

            # could be ok but only if multi-arch: no
            if ($multiarch ne 'no' || $architecture eq 'all') {

                # check multi-arch path
                my $DEB_HOST_MULTIARCH
                  = $self->profile->architectures->deb_host_multiarch;
                for my $madir (values %{$DEB_HOST_MULTIARCH}) {

                    next
                      unless $block =~ m{\W\Q$madir\E(\W|$)}xms;

                    # allow files to begin with triplet if it matches arch
                    next
                      if $file->basename =~ m{^\Q$madir\E}xms;

                    my $tagname = 'old-style-config-script-multiarch-path';
                    $tagname .= '-arch-all'
                      if $architecture eq 'all';

                    $self->hint($tagname, $file->name,
                        'full text contains architecture specific dir',$madir);

                    last;
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

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

package Lintian::files::config_scripts;

use v5.20;
use warnings;
use utf8;
use autodie;

use Lintian::SlidingWindow;

use constant EMPTY => q{};

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $MULTIARCH_DIRS = Lintian::Data->new('common/multiarch-dirs', qr/\s++/);

sub files {
    my ($self, $file) = @_;

    my $architecture = $self->processable->field('Architecture') // EMPTY;
    my $multiarch = $self->processable->field('Multi-Arch') // 'no';

    # check old style config scripts
    if (    $file->name =~ m,^usr/bin/,
        and $file->name =~ m,-config$,
        and $file->is_script
        and $file->is_regular_file) {

        # try to find some indication of
        # config file (read only one block)

        open(my $fd, '<:raw', $file->unpacked_path);
        my $sfd = Lintian::SlidingWindow->new($fd);
        my $block = $sfd->readwindow;

        # some common stuff found in config file
        if (
            $block
            and (  index($block,'flag')>-1
                or index($block,'/include/') > -1
                or index($block,'pkg-config')  > -1)
        ) {

            $self->tag('old-style-config-script', $file->name);

            # could be ok but only if multi-arch: no
            unless ($multiarch eq 'no' && $architecture ne 'all') {

                # check multi-arch path
                foreach my $wildcard ($MULTIARCH_DIRS->all) {
                    my $madir= $MULTIARCH_DIRS->value($wildcard);

                    next
                      unless $block =~ m{\W\Q$madir\E(\W|$)}xms;

                    # allow files to begin with triplet if it matches arch
                    next
                      if $file->basename =~ m{^\Q$madir\E}xms;

                    my $tagname = 'old-style-config-script-multiarch-path';
                    $tagname .= '-arch-all'
                      if $architecture eq 'all';

                    $self->tag($tagname, $file->name,
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

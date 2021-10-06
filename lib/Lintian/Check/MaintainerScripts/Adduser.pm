# maintainer_scripts::adduser -- lintian check script -*- perl -*-

# Copyright © 2020 Topi Miettinen
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

package Lintian::Check::MaintainerScripts::Adduser;

use v5.20;
use warnings;
use utf8;

use Path::Tiny;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub installable {
    my ($self) = @_;

    my @homevarrun;

    # get maintainer scripts
    my @control
      = grep { $_->is_maintainer_script }
      @{$self->processable->control->sorted_list};

    for my $file (@control) {

        next
          unless $file->is_open_ok;

        my @lines = path($file->unpacked_path)->lines;
        my $continuation = undef;

        for (@lines) {
            chomp;

            # merge lines ending with '\'
            if (defined($continuation)) {
                $_ = $continuation . $_;
                $continuation = undef;
            }
            if (/\\$/) {
                $continuation = $_;
                $continuation =~ s/\\$/ /;
                next;
            }

            # trim right
            s/\s+$//;

            # skip empty lines
            next
              if /^\s*$/;

            # skip comments
            next
              if /^[#\n]/;

            if (/adduser .*--home +\/var\/run/) {
                push(@homevarrun, $file);
                next;
            }
        }
    }

    $self->hint('adduser-with-home-var-run', $_->name) for @homevarrun;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

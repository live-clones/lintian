# debian/manual-pages -- lintian check script -*- perl -*-

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

package Lintian::Check::Debian::ManualPages;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw{none};

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    return
      if $self->processable->native;

    my $debiandir = $self->processable->patched->resolve_path('debian');
    return
      unless $debiandir;

    my @files = grep { $_->is_file } $debiandir->descendants;
    my @nopatches = grep { $_->name !~ m{^debian/patches/} } @files;

    my @manpages = grep { $_->basename =~ m{\.\d$} } @nopatches;

    for my $manpage (@manpages) {

        my $command = $manpage->basename;
        $command =~ s/ [.] \d $//x;

        $self->hint('maintainer-manual-page', $manpage->name)
          if none { $command eq $_->basename } @files;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# debian/patches/dep3 -- lintian check script -*- perl -*-

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

package Lintian::debian::patches::dep3;

use v5.20;
use warnings;
use utf8;
use autodie;

use List::MoreUtils qw(none);
use Unicode::UTF8 qw(valid_utf8 decode_utf8);

use Lintian::Deb822::File;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->name =~ m{^debian/patches/};

    return
      unless $item->is_file;

    return
      if $item->name eq 'debian/patches/series';

    my $bytes = $item->bytes;
    return
      unless length $bytes;

    my ($headerbytes) = split(/^---/m, $bytes, 2);

    return
      unless valid_utf8($headerbytes);

    my $header = decode_utf8($headerbytes);
    return
      unless length $header;

    my $deb822 = Lintian::Deb822::File->new;

    my @sections;
    eval { @sections = $deb822->parse_string($header) };
    return
      if length $@;

    return
      unless @sections;

    my @needed = qw(Forwarded Bug Applied-Upstream);
    my %last_mention;

    # use last mention when present multiple times
    for my $name (@needed) {

        # empty when field not present
        $last_mention{$name} ||= $_->value($name) for @sections;
    }

    $self->tag('send-patch', $item->name)
      if $last_mention{'Forwarded'} eq 'no'
      || none { length } (
        $last_mention{'Applied-Upstream'},
        $last_mention{'Bug'}, $last_mention{'Forwarded'});

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# libraries/shared/soname -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2012 Kees Cook
# Copyright © 2017-2020 Chris Lamb <lamby@debian.org>
# Copyright © 2021 Felix Lechner
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

package Lintian::Check::Libraries::Shared::Soname;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any none uniq);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SPACE => q{ };
const my $SLASH => q{/};

has DEB_HOST_MULTIARCH => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->architectures->deb_host_multiarch;
    });

sub installable {
    my ($self) = @_;

    return
      if $self->processable->type eq 'udeb';

    my $architecture = $self->processable->fields->value('Architecture');
    my $multiarch_component = $self->DEB_HOST_MULTIARCH->{$architecture};

    my @common_folders = qw{lib usr/lib};
    push(@common_folders, map { "$_/$multiarch_component" } @common_folders)
      if length $multiarch_component;

    my @duplicated;
    for my $item (@{$self->processable->installed->sorted_list}) {

        # For the package naming check, filter out SONAMEs where all the
        # files are at paths other than /lib, /usr/lib and /usr/lib/<MA-DIR>.
        # This avoids false positives with plugins like Apache modules,
        # which may have their own SONAMEs but which don't matter for the
        # purposes of this check.
        next
          if none { $item->dirname eq $_ . $SLASH } @common_folders;

        # Also filter out nsswitch modules
        next
          if $item->basename =~ m{^ libnss_[^.]+\.so(?:\.\d+) $}x;

        push(@duplicated, @{$item->elf->{SONAME} // []});
    }

    my @sonames = uniq @duplicated;

    # try to strip transition strings
    my $shortened_name = $self->processable->name;
    $shortened_name =~ s/c102\b//;
    $shortened_name =~ s/c2a?\b//;
    $shortened_name =~ s/\dg$//;
    $shortened_name =~ s/gf$//;
    $shortened_name =~ s/v[5-6]$//; # GCC-5 / libstdc++6 C11 ABI breakage
    $shortened_name =~ s/-udeb$//;
    $shortened_name =~ s/^lib64/lib/;

    my $match_found = 0;
    for my $soname (@sonames) {

        $soname =~ s/ ([0-9]) [.]so[.] /$1-/x;
        $soname =~ s/ [.]so (?:[.]|\z) //x;
        $soname =~ s/_/-/g;

        my $lowercase = lc $soname;

        $match_found = any { $lowercase eq $_ }
        ($self->processable->name, $shortened_name);

        last
          if $match_found;
    }

    $self->hint('package-name-doesnt-match-sonames',
        join($SPACE, sort @sonames))
      if @sonames && !$match_found;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

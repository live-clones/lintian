# fields/multi-arch -- lintian check script (rewrite) -*- perl -*-
#
# Copyright © 2004 Marc Brockschmidt
#
# Parts of the code were taken from the old check script, which
# was Copyright © 1998 Richard Braakman (also licensed under the
# GPL 2 or higher)
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

package Lintian::Check::Fields::MultiArch;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(uniq any);
use Unicode::UTF8 qw(decode_utf8);

use Lintian::IPC::Run3 qw(safe_qx);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SPACE => q{ };

sub source {
    my ($self) = @_;

    my $pkg = $self->processable->name;
    my $processable = $self->processable;

    for my $bin ($processable->debian_control->installables) {

        next
          unless ($processable->debian_control->installable_fields($bin)
            ->value('Multi-Arch')) eq 'same';

        my $wildcard = $processable->debian_control->installable_fields($bin)
          ->value('Architecture');
        my @arches   = split(
            $SPACE,
            decode_utf8(
                safe_qx(
                    'dpkg-architecture', '--match-wildcard',
                    $wildcard,           '--list-known'
                )));

        # include original wildcard
        push(@arches, $wildcard);

        foreach my $arch (uniq @arches) {

            my $specific = "debian/$bin.lintian-overrides.$arch";

            $self->hint('multi-arch-same-package-has-arch-specific-overrides',
                $specific)
              if $processable->patched->resolve_path($specific);
        }
    }

    return;
}

sub installable {
    my ($self) = @_;

    my $fields = $self->processable->fields;

    if ($self->processable->name =~ /^x?fonts-/) {

        my $multi = $fields->value('Multi-Arch') || 'no';

        $self->hint('font-package-not-multi-arch-foreign')
          unless any { $multi eq $_ } qw(foreign allowed);
    }

    return
      unless $fields->declares('Multi-Arch');

    my $multi = $fields->unfolded_value('Multi-Arch');

    if ($fields->declares('Architecture')) {

        my $architecture = $fields->unfolded_value('Architecture');

        $self->hint('illegal-multi-arch-value', $architecture, $multi)
          if $architecture eq 'all' && $multi eq 'same';
    }

    return;
}

sub always {
    my ($self) = @_;

    my $fields = $self->processable->fields;

    return
      unless $fields->declares('Multi-Arch');

    my $multi = $fields->unfolded_value('Multi-Arch');

    $self->hint('unknown-multi-arch-value', $self->processable->name, $multi)
      unless any { $multi eq $_ } qw(no foreign allowed same);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

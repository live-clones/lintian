# triggers -- lintian check script -*- perl -*-

# Copyright © 2017 Niels Thykier
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

package Lintian::triggers;

use v5.20;
use warnings;
use utf8;
use autodie qw(open);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub _parse_trigger_types {
    my ($key, $val) = @_;
    my %values;
    for my $kvstr (split(m/\s*,\s*/, $val)) {
        my ($k, $v) = split(m/\s*=\s*/, $kvstr, 2);
        $values{$k} = $v;
    }
    if (exists($values{'implicit-await'})) {
        die
"Invalid trigger-types: $key is defined as implicit-await but not await"
          if $values{'implicit-await'} and not $values{'await'};
    }
    return \%values;
}

sub installable {
    my ($self) = @_;

    my $processable = $self->processable;

    my $TRIGGER_TYPES = $self->profile->load_data('triggers/trigger-types',
        qr/\s*\Q=>\E\s*/, \&_parse_trigger_types);

    my $triggers_file = $processable->control->lookup('triggers');
    return if not $triggers_file or not $triggers_file->is_open_ok;
    open(my $fd, '<', $triggers_file->unpacked_path);
    my %seen_triggers;
    while (my $line = <$fd>) {

        # trim both ends
        $line =~ s/^\s+|\s+$//g;

        next if $line =~ m/^(?:\s*)(?:#.*)?$/;
        my ($trigger_type, $arg) = split(m/\s++/, $line, 2);
        my $trigger_info = $TRIGGER_TYPES->value($trigger_type);
        if (not $trigger_info) {
            $self->hint('unknown-trigger', $line, "(line $.)");
            next;
        }
        if ($trigger_info->{'implicit-await'}) {
            $self->hint('uses-implicit-await-trigger', $line, "(line $.)");
        }
        if (defined(my $prev_info = $seen_triggers{$arg})) {
            my ($prev_line, $prev_line_no) = @{$prev_info};
            $self->hint('repeated-trigger-name', $line, "(line $.)", 'vs',
                $prev_line,"(line $prev_line_no)");
            next;
        }
        $seen_triggers{$arg} = [$line, $.];
    }
    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

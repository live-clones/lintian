# -*- perl -*-
#
# Copyright © 2008 Niko Tyni
# Copyright © 2018 Chris Lamb <lamby@debian.org>
# Copyright © 2021 Felix Lechner
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::Data::Provides::MailTransportAgent;

use v5.20;
use warnings;
use utf8;

use Carp qw(carp);
use Const::Fast;
use List::SomeUtils qw(first_value any);
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

const my $SLASH => q{/};

const my $NEWLINE => qq{\n};

=head1 NAME

Lintian::Data::Provides::MailTransportAgent - Lintian interface for mail transport agents.

=head1 SYNOPSIS

    use Lintian::Data::Provides::MailTransportAgent;

=head1 DESCRIPTION

This module provides a way to load data files for mail transport agents.

=head1 INSTANCE METHODS

=over 4

=item title

=item location

=item mail_transport_agents

=item deb822_by_installable_name

=cut

has title => (
    is => 'rw',
    default => 'Mail Transport Agents'
);

has location => (
    is => 'rw',
    default => 'fields/mail-transport-agents'
);

has mail_transport_agents => (is => 'rw', default => sub { [] });

=item all

=cut

sub all {
    my ($self) = @_;

    return keys %{$self->mail_transport_agents};
}

=item load

=cut

sub load {
    my ($self, $search_space, $our_vendor) = @_;

    my @candidates = map { $_ . $SLASH . $self->location } @{$search_space};
    my $path = first_value { -e } @candidates;

    unless (length $path) {
        carp encode_utf8('Unknown data file: ' . $self->location);
        return 0;
    }

    open(my $fd, '<:utf8_strict', $path)
      or die encode_utf8("Cannot open $path: $!");

    my $position = 1;
    while (my $line = <$fd>) {

        # trim both ends
        $line =~ s/^\s+|\s+$//g;

        next
          unless length $line;

        next
          if $line =~ m{^ [#]}x;

        my $agent = $line;

        push(@{$self->mail_transport_agents}, $agent);

    } continue {
        ++$position;
    }

    close $fd;

    return 1;
}

=item refresh

=cut

sub refresh {
    my ($self, $archive, $basedir) = @_;

    my @mail_transport_agents;

    # neutral sort order
    local $ENV{LC_ALL} = 'C';

    my $port = 'amd64';

    my $deb822_by_installable_name
      = $archive->deb822_packages_by_installable_name('sid', 'main', $port);

    for my $installable_name (keys %{$deb822_by_installable_name}) {

        my $deb822 = $deb822_by_installable_name->{$installable_name};

        my @provides = $deb822->trimmed_list('Provides', qr{ \s* , \s* }x);

        push(@mail_transport_agents, $installable_name)
          if any { $_ eq 'mail-transport-agent' } @provides;
    }

    my $text = encode_utf8(<<'EOF');
# Packages that provide mail-transport-agent
#
EOF

    $text .= encode_utf8($_ . $NEWLINE)for sort @mail_transport_agents;

    my $datapath = "$basedir/" . $self->location;
    my $parentdir = path($datapath)->parent->stringify;
    path($parentdir)->mkpath
      unless -e $parentdir;

    # already in UTF-8
    path($datapath)->spew($text);

    return 1;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

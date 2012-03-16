# -*- perl -*-
# Lintian::Architecture

# Copyright (C) 2011 Niels Thykier
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

package Lintian::Architecture;

use strict;
use warnings;

use Lintian::Data;

use base 'Exporter';
our (@EXPORT_OK, %EXPORT_TAGS);

@EXPORT_OK = (qw(
    is_arch_wildcard
    is_arch
    is_arch_or_wildcard
    expand_arch_wildcard
    wildcard_includes_arch
));

%EXPORT_TAGS = (all => \@EXPORT_OK);


=head1 NAME

Lintian::Architecture -- Lintian API for handling architectures and wilcards

=head1 SYNOPSIS

 use Lintian::Architecture qw(:all);
 
 print "arch\n" if is_arch ('i386');
 print "wildcard\n" if is_arch_wildcard ('any');
 print "either arch or wc\n" if is_arch_or_wildcard ('linux-any');
 foreach my $arch (expand_arch_wildcard ('any')) {
     print "any expands to $arch\n";
 }

=head1 DESCRIPTION

Lintian API for checking and expanding architectures and architecture
wildcards.

=head1 FUNCTIONS

The following methods are exportable:

=over 4

=cut

# Setup code

# Valid architecture wildcards.
my %ARCH_WILDCARDS = ();

sub _parse_arch {
    my ($archstr, $raw) = @_;
    my ($os, $arch) = split /\s++/o, $raw;
    # map $os-any (e.g. "linux-any") and any-$arch (e.g. "any-amd64") to
    # the relevant architectures.
    $ARCH_WILDCARDS{"$os-any"}->{$archstr} = 1;
    $ARCH_WILDCARDS{"any-$arch"}->{$archstr} = 1;
    $ARCH_WILDCARDS{'any'}->{$archstr} = 1;
}

my $ARCH_RAW = Lintian::Data->new ('common/architectures', qr/\s*+\Q||\E\s*+/o,
                                   \&_parse_arch);

=item is_arch_wildcard ($wc)

Returns a truth value if $wc is an architecture wildcard.

Note: 'any' is considered a wildcard and not an architecture.

=cut

sub is_arch_wildcard {
    my ($wc) = @_;
    $ARCH_RAW->known ('any') unless %ARCH_WILDCARDS;
    return exists $ARCH_WILDCARDS{$wc} ? 1 : 0;
}

=item is_arch ($arch)

Returns a truth value if $arch is an architecture (but not an
architecture wildcard).

Note that 'any' is considered a wildcard and not an architecture.

=cut

sub is_arch {
    my ($arch) = @_;
    return 1 if $arch eq 'all';
    return ($arch ne 'any' && $ARCH_RAW->known($arch)) ? 1 : 0;
}

=item is_arch_or_wildcard ($arch)

Returns a truth value if $arch is either an architecture or an
architecture wildcard.

Shorthand for:

 is_arch ($arch) || is_arch_wildcard ($arch)

=cut

sub is_arch_or_wildcard {
    my ($arch) = @_;
    return is_arch($arch) || is_arch_wildcard($arch);
}

=item expand_arch_wildcard ($wc)

Returns a list of architectures that this wildcard expands to.  No
order is guaranteed (even between calls).  Returned values must not be
modified.

Note: This list is based on the architectures in Lintian's data file.
However, many of these are not supported or used in Debian or any of
its derivaties.

=cut

sub expand_arch_wildcard {
    my ($wc) = @_;
    # Load the wildcards if it has not been done yet.
    $ARCH_RAW->known ('any') unless %ARCH_WILDCARDS;
    return () unless exists $ARCH_WILDCARDS{$wc};
    return keys %{ $ARCH_WILDCARDS{$wc} };
}

=item wildcard_include_arch ($wc, $arch)

Returns a truth value if $arch is included in the list of
architectures that $wc expands to.

This is generally faster than

  grep { $_ eq $arch } expand_arch_wildcard ($wc)

=cut

sub wildcard_includes_arch {
    my ($wc, $arch) = @_;
    # Load the wildcards if it has not been done yet.
    $ARCH_RAW->known ('any') unless %ARCH_WILDCARDS;
    return exists $ARCH_WILDCARDS{$wc}->{$arch} ? 1 : 0;
}

=back



=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

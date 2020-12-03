# -*- perl -*-
# Lintian::Architecture::Analyzer

# Copyright © 2011 Niels Thykier
# Copyright © 2020 Felix Lechner
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

package Lintian::Architecture::Analyzer;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

=encoding utf-8

=head1 NAME

Lintian::Architecture::Analyzer -- Lintian API for handling architectures and wildcards

=head1 SYNOPSIS

 use Lintian::Architecture::Analyzer;

=head1 DESCRIPTION

Lintian API for checking and expanding architectures and architecture
wildcards.  The functions are backed by a L<data|Lintian::Data> file,
so it may be out of date (use private/refresh-archs to update it).

Generally all architecture names are in the format "$os-$architecture" and
wildcards are "$os-any" or "any-$cpu", though there are exceptions:

=over 4

=item * "all" is the "architecture independent" architecture.

Source: Policy §5.6.8 (v3.9.3)

=item * "any" is a wildcard matching any architecture except "all".

Source: Policy §5.6.8 (v3.9.3)

=item * All other cases of "$architecture" are short for "linux-$architecture"

Source: Policy §11.1 (v3.9.3)

=back

Note that the architecture and cpu name are not always identical
(example architecture "armhf" has cpu name "arm").

=head1 FUNCTIONS

The following methods are exportable:

=over 4

=item profile
=item C<spaced>
=item C<wildcards>
=item C<names>

=cut

has profile => (is => 'rw');

has spaced => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        croak encode_utf8('No profile')
          unless defined $self->profile;

        return $self->profile->load_data('common/architectures',
            qr/\s*+\Q||\E\s*+/);
    });

# Valid architecture wildcards.
has wildcards => (
    is => 'rw',
    lazy => 1,
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub {
        my ($self) = @_;

        my %wildcards;

        for my $hyphenated ($self->spaced->all) {

            my $components = $self->spaced->value($hyphenated);

            # NB: "$os-$cpu" ne $hyphenated in some cases
            my ($os, $cpu) = split(/\s+/, $components);

   # map $os-any (e.g. "linux-any") and any-$architecture (e.g. "any-amd64") to
   # the relevant architectures.
            $wildcards{"$os-any"}{$hyphenated} = 1;
            $wildcards{"any-$cpu"}{$hyphenated} = 1;
            $wildcards{'any'}{$hyphenated} = 1;
        }

        return \%wildcards;
    });

# Maps aliases to the "original" arch name.
# (e.g. "linux-amd64" => "amd64")
has names => (
    is => 'rw',
    lazy => 1,
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub {
        my ($self) = @_;

        my %names;

        for my $hyphenated ($self->spaced->all) {

            my $components = $self->spaced->value($hyphenated);

            my ($os, $cpu) = split(/\s+/, $components);

            # NB: "$os-$cpu" ne $hyphenated in some cases
            $names{$hyphenated} = $hyphenated;

            if ($os eq 'linux') {

                # Per Policy §11.1 (3.9.3):
                #
                #"""[architecture] strings are in the format "os-arch", though
                # the OS part is sometimes elided, as when the OS is Linux."""
                #
                # i.e. "linux-amd64" and "amd64" are aliases, so handle them
                # as such.  Currently, dpkg-architecture -L gives us "amd64"
                # but in case it changes to "linux-amd64", we are prepared.

                if ($hyphenated =~ /^linux-/) {
                    # It may be temping to use $cpu here, but it does not work
                    # for (e.g.) arm based architectures.  Instead extract the
                    # "short" architecture name from $hyphenated
                    my (undef, $short) = split(/-/, $hyphenated, 2);
                    $names{$short} = $hyphenated;

                } else {
                    # short string in $hyphenated
                    my $long = "$os-$hyphenated";
                    $names{$long} = $hyphenated;
                }
            }
        }

        return \%names;
    });

=item is_arch_wildcard ($wildcard)

Returns a truth value if $wildcard is a known architecture wildcard.

Note: 'any' is considered a wildcard and not an architecture.

=cut

sub is_arch_wildcard {
    my ($self, $wildcard) = @_;

    return exists $self->wildcards->{$wildcard};
}

=item is_arch ($architecture)

Returns a truth value if $architecture is (an alias of) a Debian machine
architecture OR the special value "all".  It returns a false value for
architecture wildcards (including "any") and unknown architectures.

=cut

sub is_arch {
    my ($self, $architecture) = @_;

    return 0
      if $architecture eq 'any';

    return 1
      if exists $self->names->{$architecture};

    return 1
      if $architecture eq 'all';

    return 0;
}

=item is_arch_or_wildcard ($architecture)

Returns a truth value if $architecture is either an architecture or an
architecture wildcard.

Shorthand for:

 is_arch ($architecture) || is_arch_wildcard ($architecture)

=cut

sub is_arch_or_wildcard {
    my ($self, $architecture) = @_;

    return 1
      if $self->is_arch($architecture);

    return 1
      if $self->is_arch_wildcard($architecture);

    return 0;
}

=item expand_arch_wildcard ($wildcard)

Returns a list of architectures that this wildcard expands to.  No
order is guaranteed (even between calls).  Returned values must not be
modified.

Note: This list is based on the architectures in Lintian's data file.
However, many of these are not supported or used in Debian or any of
its derivatives.

The returned values matches the list generated by dpkg-architecture -L,
so the returned list may use (e.g.) "amd64" for "linux-amd64".

=cut

sub expand_arch_wildcard {
    my ($self, $wildcard) = @_;

    return keys %{ $self->wildcards->{$wildcard} // {} };
}

=item wildcard_includes_arch ($wildcard, $architecture)

Returns a truth value if $architecture is included in the list of
architectures that $wildcard expands to.

This is generally faster than

  grep { $_ eq $architecture } expand_arch_wildcard ($wildcard)

It also properly handles cases like "linux-amd64" and "amd64" being
aliases.

=cut

sub wildcard_includes_arch {
    my ($self, $wildcard, $architecture) = @_;

    $architecture = $self->names->{$architecture}
      if exists $self->names->{$architecture};

    return exists $self->wildcards->{$wildcard}{$architecture};
}

=item valid_wildcard

=cut

sub valid_wildcard {
    my ($self, $wildcard) = @_;

    # strip any negative prefix
    $wildcard =~ s/^!//;

    return $self->is_arch($wildcard) || $self->is_arch_wildcard($wildcard);
}

=item wildcard_matches

=cut

sub wildcard_matches {
    my ($self, $wildcard, $architecture) = @_;

    # look for negative prefix and strip
    my $match_wanted = !($wildcard =~ s/^!//);

    return $match_wanted
      if $wildcard eq $architecture
      || ( $self->is_arch_wildcard($wildcard)
        && $self->wildcard_includes_arch($wildcard, $architecture));

    return !$match_wanted;
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

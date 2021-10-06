# -*- perl -*-

# Copyright © 2011-2012 Niels Thykier <niels@thykier.net>
#  - Based on a shell script by Raphael Geissert <atomo64@gmail.com>
# Copyright © 2020-2021 Felix Lechner
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

package Lintian::Data::Architectures;

use v5.20;
use warnings;
use utf8;

use Carp qw(croak);
use Const::Fast;
use JSON::MaybeXS;
use List::SomeUtils qw(first_value);
use Path::Tiny;
use Time::Piece;
use Unicode::UTF8 qw(decode_utf8 encode_utf8);

use Lintian::IPC::Run3 qw(safe_qx);

use Moo;
use namespace::clean;

const my $SLASH => q{/};

=encoding utf-8

=head1 NAME

Lintian::Data::Architectures -- Lintian API for handling architectures and wildcards

=head1 SYNOPSIS

 use Lintian::Data::Architectures;

=head1 DESCRIPTION

Lintian API for checking and expanding architectures and architecture
wildcards.  The functions are backed by a L<data|Lintian::Data> file,
so it may be out of date (use private/refresh-archs to update it).

Generally all architecture names are in the format "$os-$architecture" and
wildcards are "$os-any" or "any-$cpu", though there are exceptions:

Note that the architecture and cpu name are not always identical
(example architecture "armhf" has cpu name "arm").

=head1 INSTANCE METHODS

=over 4

=item location

=item preamble

=item host_variables

=item C<wildcards>

=item C<names>

=cut

has location => (
    is => 'rw',
    default => 'architectures/host.json'
);

has preamble => (is => 'rw');
has host_variables => (is => 'rw');

has deb_host_multiarch => (
    is => 'rw',
    lazy => 1,
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub {
        my ($self) = @_;

        my %deb_host_multiarch;

        $deb_host_multiarch{$_}
          = $self->host_variables->{$_}{DEB_HOST_MULTIARCH}
          for keys %{$self->host_variables};

        return \%deb_host_multiarch;
    });

# The list of directories searched by default by the dynamic linker.
# Packages installing shared libraries into these directories must call
# ldconfig, must have shlibs files, and must ensure those libraries have
# proper SONAMEs.
#
# Directories listed here must not have leading slashes.
#
# On the topic of multi-arch dirs.  Hopefully including the ones not
# native to the local platform won't hurt.
#
# See Bug#469301 and Bug#464796 for more details.
#
has ldconfig_folders => (
    is => 'rw',
    lazy => 1,
    coerce => sub { my ($arrayref) = @_; return ($arrayref // {}); },
    default => sub {
        my ($self) = @_;

        my @multiarch = values %{$self->deb_host_multiarch};
        my @ldconfig_folders = map { ("lib/$_", "usr/lib/$_") } @multiarch;

        my @always = qw{
          lib
          lib32
          lib64
          libx32
          usr/lib
          usr/lib32
          usr/lib64
          usr/libx32
          usr/local/lib
        };
        push(@ldconfig_folders, @always);

        my @with_slash = map { $_ . $SLASH } @ldconfig_folders;

        return \@with_slash;
    });

# Valid architecture wildcards.
has wildcards => (
    is => 'rw',
    lazy => 1,
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub {
        my ($self) = @_;

        my %wildcards;

        for my $hyphenated (keys %{$self->host_variables}) {

            my $variables = $self->host_variables->{$hyphenated};

            # NB: "$os-$cpu" is not always equal to $hyphenated
            my $abi = $variables->{DEB_HOST_ARCH_ABI};
            my $libc = $variables->{DEB_HOST_ARCH_LIBC};
            my $os = $variables->{DEB_HOST_ARCH_OS};
            my $cpu = $variables->{DEB_HOST_ARCH_CPU};

   # map $os-any (e.g. "linux-any") and any-$architecture (e.g. "any-amd64") to
   # the relevant architectures.
            $wildcards{'any'}{$hyphenated} = 1;

            $wildcards{'any-any'}{$hyphenated} = 1;
            $wildcards{"any-$cpu"}{$hyphenated} = 1;
            $wildcards{"$os-any"}{$hyphenated} = 1;

            $wildcards{'any-any-any'}{$hyphenated} = 1;
            $wildcards{"any-any-$cpu"}{$hyphenated} = 1;
            $wildcards{"any-$os-any"}{$hyphenated} = 1;
            $wildcards{"any-$os-$cpu"}{$hyphenated} = 1;
            $wildcards{"$libc-any-any"}{$hyphenated} = 1;
            $wildcards{"$libc-any-$cpu"}{$hyphenated} = 1;
            $wildcards{"$libc-$os-any"}{$hyphenated} = 1;

            $wildcards{'any-any-any-any'}{$hyphenated} = 1;
            $wildcards{"any-any-any-$cpu"}{$hyphenated} = 1;
            $wildcards{"any-any-$os-any"}{$hyphenated} = 1;
            $wildcards{"any-any-$os-$cpu"}{$hyphenated} = 1;
            $wildcards{"any-$libc-any-any"}{$hyphenated} = 1;
            $wildcards{"any-$libc-any-$cpu"}{$hyphenated} = 1;
            $wildcards{"any-$libc-$os-any"}{$hyphenated} = 1;
            $wildcards{"any-$libc-$os-$cpu"}{$hyphenated} = 1;
            $wildcards{"$abi-any-any-any"}{$hyphenated} = 1;
            $wildcards{"$abi-any-any-$cpu"}{$hyphenated} = 1;
            $wildcards{"$abi-any-$os-any"}{$hyphenated} = 1;
            $wildcards{"$abi-any-$os-$cpu"}{$hyphenated} = 1;
            $wildcards{"$abi-$libc-any-any"}{$hyphenated} = 1;
            $wildcards{"$abi-$libc-any-$cpu"}{$hyphenated} = 1;
            $wildcards{"$abi-$libc-$os-any"}{$hyphenated} = 1;
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

        for my $hyphenated (keys %{$self->host_variables}) {

            my $variables = $self->host_variables->{$hyphenated};

            $names{$hyphenated} = $hyphenated;

            # NB: "$os-$cpu" ne $hyphenated in some cases
            my $os = $variables->{DEB_HOST_ARCH_OS};
            my $cpu = $variables->{DEB_HOST_ARCH_CPU};

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

=item is_wildcard ($wildcard)

Returns a truth value if $wildcard is a known architecture wildcard.

Note: 'any' is considered a wildcard and not an architecture.

=cut

sub is_wildcard {
    my ($self, $wildcard) = @_;

    return exists $self->wildcards->{$wildcard};
}

=item is_release_architecture ($architecture)

Returns a truth value if $architecture is (an alias of) a Debian machine
architecture.  It returns a false value for
architecture wildcards (including "any") and unknown architectures.

=cut

sub is_release_architecture {
    my ($self, $architecture) = @_;

    return exists $self->names->{$architecture};
}

=item expand_wildcard ($wildcard)

Returns a list of architectures that this wildcard expands to.  No
order is guaranteed (even between calls).  Returned values must not be
modified.

Note: This list is based on the architectures in Lintian's data file.
However, many of these are not supported or used in Debian or any of
its derivatives.

The returned values matches the list generated by dpkg-architecture -L,
so the returned list may use (e.g.) "amd64" for "linux-amd64".

=cut

sub expand_wildcard {
    my ($self, $wildcard) = @_;

    return keys %{ $self->wildcards->{$wildcard} // {} };
}

=item wildcard_includes ($wildcard, $architecture)

Returns a truth value if $architecture is included in the list of
architectures that $wildcard expands to.

This is generally faster than

  grep { $_ eq $architecture } expand_arch_wildcard ($wildcard)

It also properly handles cases like "linux-amd64" and "amd64" being
aliases.

=cut

sub wildcard_includes {
    my ($self, $wildcard, $architecture) = @_;

    $architecture = $self->names->{$architecture}
      if exists $self->names->{$architecture};

    return exists $self->wildcards->{$wildcard}{$architecture};
}

=item valid_restriction

=cut

sub valid_restriction {
    my ($self, $restriction) = @_;

    # strip any negative prefix
    $restriction =~ s/^!//;

    return
         $self->is_release_architecture($restriction)
      || $self->is_wildcard($restriction)
      || $restriction eq 'all';
}

=item restriction_matches

=cut

sub restriction_matches {
    my ($self, $restriction, $architecture) = @_;

    # look for negative prefix and strip
    my $match_wanted = !($restriction =~ s/^!//);

    return $match_wanted
      if $restriction eq $architecture;

    return $match_wanted
      if $self->is_wildcard($restriction)
      && $self->wildcard_includes($restriction, $architecture);

    return !$match_wanted;
}

=item load

=cut

sub load {
    my ($self, $search_space, $our_vendor) = @_;

    my @candidates = map { $_ . $SLASH . $self->location } @{$search_space};
    my $path = first_value { -e } @candidates;

    croak encode_utf8('Unknown data file: ' . $self->location)
      unless length $path;

    my $json = path($path)->slurp;
    my $data = decode_json($json);

    $self->preamble($data->{preamble});
    $self->host_variables($data->{'variables'});

    return;
}

=item refresh

=cut

sub refresh {
    my ($self, $basedir) = @_;

    local $ENV{LC_ALL} = 'C';
    delete local $ENV{DEB_HOST_ARCH};

    my $version_output= decode_utf8(safe_qx(qw{dpkg-architecture --version}));
    my ($dpkg_version) = split(/\n/, $version_output);

    # retain only the version number
    $dpkg_version =~ s/^.*\s(\S+)[.]$/$1/s;

    my @architectures
      = split(/\n/, decode_utf8(safe_qx(qw{dpkg-architecture --list-known})));
    chomp for @architectures;

    my %variables;
    for my $architecture (@architectures) {

        my @lines= split(
            /\n/,
            decode_utf8(
                safe_qx(qw{dpkg-architecture --host-arch}, $architecture)));

        for my $line (@lines) {
            my ($key, $value) = split(/=/, $line, 2);

            $variables{$architecture}{$key} = $value
              if $key =~ /^DEB_HOST_/;
        }
    }

    my %preamble;
    $preamble{title} = 'DEB_HOST_* Variables From Dpkg';
    $preamble{'dpkg-version'} = $dpkg_version;
    $preamble{'last-update'} = gmtime->datetime . 'Z';

    my %all;
    $all{preamble} = \%preamble;
    $all{'variables'} = \%variables;

    # convert to UTF-8 prior to encoding in JSON
    my $encoder = JSON->new;
    $encoder->canonical;
    $encoder->utf8;
    $encoder->pretty;

    my $json = $encoder->encode(\%all);

    my $datapath = "$basedir/" . $self->location;
    my $parentdir = path($datapath)->parent->stringify;
    path($parentdir)->mkpath
      unless -e $parentdir;

    # already in UTF-8
    path($datapath)->spew($json);

    return 1;
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

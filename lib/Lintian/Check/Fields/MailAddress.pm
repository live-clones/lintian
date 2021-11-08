# fields/mail-address -- lintian check script (rewrite) -*- perl -*-
#
# Copyright © 2004 Marc Brockschmidt
# Copyright © 2020 Felix Lechner
# Copyright © 2020 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Fields::MailAddress;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Data::Validate::Domain;
use Email::Address::XS;
use List::SomeUtils qw(any all);
use List::UtilsBy qw(uniq_by);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $QA_GROUP_PHRASE => 'Debian QA Group';
const my $QA_GROUP_ADDRESS => 'packages@qa.debian.org';
const my $ARROW => q{ -> };

# list of addresses known to bounce messages from role accounts
my @KNOWN_BOUNCE_ADDRESSES = qw(
  ubuntu-devel-discuss@lists.ubuntu.com
);

sub always {
    my ($self) = @_;

    my @singles = qw(Maintainer Changed-By);
    my @groups = qw(Uploaders);

    my @singles_present
      = grep { $self->processable->fields->declares($_) } @singles;
    my @groups_present
      = grep { $self->processable->fields->declares($_) } @groups;

    my %parsed;
    for my $role (@singles_present, @groups_present) {

        my $value = $self->processable->fields->value($role);
        $parsed{$role} = [Email::Address::XS->parse($value)];
    }

    for my $role (keys %parsed) {

        my @invalid = grep { !$_->is_valid } @{$parsed{$role}};
        $self->hint('malformed-contact', $role, $_->original)for @invalid;

        my @valid = grep { $_->is_valid } @{$parsed{$role}};
        my @unique = uniq_by { $_->format } @valid;

        $self->check_single_address($role, $_) for @unique;
    }

    for my $role (@singles_present) {
        $self->hint('too-many-contacts', $role,
            $self->processable->fields->value($role))
          if @{$parsed{$role}} > 1;
    }

    for my $role (@groups_present) {
        my @valid = grep { $_->is_valid } @{$parsed{$role}};
        my @addresses = map { $_->address } @valid;

        my %count;
        $count{$_}++ for @addresses;
        my @duplicates = grep { $count{$_} > 1 } keys %count;

        $self->hint('duplicate-contact', $role, $_) for @duplicates;
    }

    return;
}

sub check_single_address {
    my ($self, $role, $parsed) = @_;

    $self->hint('mail-contact', $role, $parsed->format);

    unless (all { length } ($parsed->address, $parsed->user, $parsed->host)) {
        $self->hint('incomplete-mail-address', $role, $parsed->format);
        return;
    }

    $self->hint('bogus-mail-host', $role, $parsed->address)
      unless is_domain($parsed->host, {domain_disable_tld_validation => 1});

    $self->hint('mail-address-loops-or-bounces',$role, $parsed->address)
      if any { $_ eq $parsed->address } @KNOWN_BOUNCE_ADDRESSES;

    unless (length $parsed->phrase) {
        $self->hint('no-phrase', $role, $parsed->format);
        return;
    }

    $self->hint('root-in-contact', $role, $parsed->format)
      if $parsed->user eq 'root' || $parsed->phrase eq 'root';

    # Debian QA Group
    $self->hint('faulty-debian-qa-group-phrase',
        $role, $parsed->phrase . $ARROW . $QA_GROUP_PHRASE)
      if $parsed->address eq $QA_GROUP_ADDRESS
      && $parsed->phrase ne $QA_GROUP_PHRASE;

    $self->hint('faulty-debian-qa-group-address',
        $role, $parsed->address . $ARROW . $QA_GROUP_ADDRESS)
      if ( $parsed->phrase =~ /\bdebian\s+qa\b/i
        && $parsed->address ne $QA_GROUP_ADDRESS)
      || $parsed->address eq 'debian-qa@lists.debian.org';

    $self->hint('mailing-list-on-alioth', $role, $parsed->address)
      if $parsed->host eq 'lists.alioth.debian.org';

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

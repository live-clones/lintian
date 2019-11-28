# fields/version -- lintian check script (rewrite) -*- perl -*-
#
# Copyright (C) 2004 Marc Brockschmidt
#
# Parts of the code were taken from the old check script, which
# was Copyright (C) 1998 Richard Braakman (also licensed under the
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

package Lintian::fields::version;

use strict;
use warnings;
use autodie;

use Dpkg::Version qw(version_check);

use Lintian::Relation::Version qw(versions_compare);

use Moo;
use namespace::clean;

with 'Lintian::Check';

our $DERIVATIVE_VERSIONS= Lintian::Data->new('fields/derivative-versions',
    qr/\s*~~\s*/, sub { $_[1]; });

our $PERL_CORE_PROVIDES = Lintian::Data->new('fields/perl-provides', '\s+');

sub source {
    my ($self) = @_;

    my $processable = $self->processable;

    my $version = $processable->unfolded_field('version');

    return
      unless defined $version;

    # Checks for the dfsg convention for repackaged upstream
    # source.  Only check these against the source package to not
    # repeat ourselves too much.
    if ($version =~ /dfsg/ and $processable->native) {
        $self->tag('dfsg-version-in-native-package', $version);
    } elsif ($version =~ /\.dfsg/) {
        $self->tag('dfsg-version-with-period', $version);
    } elsif ($version =~ /dsfg/) {
        $self->tag('dfsg-version-misspelled', $version);
    }

    $self->tag('binary-nmu-debian-revision-in-source', $version)
      if $version =~ /\+b\d+$/;

    my $dversion = Dpkg::Version->new($version);

    return
      unless $dversion->is_valid;

    my ($epoch, $upstream, $debian)
      = ($dversion->epoch, $dversion->version, $dversion->revision);

    unless ($processable->native) {
        foreach my $re ($DERIVATIVE_VERSIONS->all) {

            next
              if $version =~ m/$re/;

            my $explanation = $DERIVATIVE_VERSIONS->value($re);

            $self->tag('invalid-version-number-for-derivative',
                $version,"($explanation)");
        }
    }

    return;
}

sub always {
    my ($self) = @_;

    my $type = $self->type;
    my $processable = $self->processable;

    my $version = $processable->unfolded_field('version');

    unless (defined $version) {
        $self->tag('no-version-field');
        return;
    }

    my $dversion = Dpkg::Version->new($version);
    unless ($dversion->is_valid) {
        $self->tag('bad-version-number', $version);
        return;
    }

    my ($epoch, $upstream, $debian)
      = ($dversion->epoch, $dversion->version, $dversion->revision);

    # Dpkg::Version sets the debian revision to 0 if there is
    # no revision.  So we need to check if the raw version
    # ends with "-0".
    $self->tag('debian-revision-should-not-be-zero', $version)
      if $version =~ m/-0$/o;

    my $ubuntu;
    if($debian =~ m/^(?:[^.]+)(?:\.[^.]+)?(?:\.[^.]+)?(\..*)?$/o){
        my $extra = $1;
        if (
            defined $extra
            && $debian =~ m/\A
                            (?:[^.]+ubuntu[^.]+)(?:\.\d+){1,3}(\..*)?
                            \Z/oxsm
        ) {
            $ubuntu = 1;
            $extra = $1;
        }

        $self->tag('debian-revision-not-well-formed', $version)
          if defined $extra;

    } else {
        $self->tag('debian-revision-not-well-formed', $version);
    }

    if ($type eq 'source') {

        $self->tag('binary-nmu-debian-revision-in-source', $version)
          if $debian =~ /^[^.-]+\.[^.-]+\./o and not $ubuntu;
    }

    my $name = $processable->field('package');
    if (   $name
        && $PERL_CORE_PROVIDES->known($name)
        && perl_core_has_version($name, '>=', "$epoch:$upstream")) {

        my $core_version = $PERL_CORE_PROVIDES->value($name);

        $self->tag('package-superseded-by-perl', "with $core_version");
    }

    return;
}

sub perl_core_has_version {
    my ($package, $op, $version) = @_;

    my $core_version = $PERL_CORE_PROVIDES->value($package);

    return 0
      unless defined $core_version && version_check($version);

    return versions_compare($core_version, $op, $version);
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

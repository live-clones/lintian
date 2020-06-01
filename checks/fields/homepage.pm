# fields/homepage -- lintian check script (rewrite) -*- perl -*-
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

package Lintian::fields::homepage;

use v5.20;
use warnings;
use utf8;
use autodie;

use Lintian::Data ();

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $BAD_HOMEPAGES = Lintian::Data->new('fields/bad-homepages');

sub source {
    my ($self) = @_;

    my $processable = $self->processable;

    my $homepage = $processable->unfolded_field('homepage');

    unless (defined $homepage) {

        return
          if $processable->native;

        my $binary_has_homepage_field = 0;
        for my $binary ($processable->binaries) {

            if (defined $processable->binary_field($binary, 'homepage')) {
                $binary_has_homepage_field = 1;
                last;
            }
        }

        if ($binary_has_homepage_field) {
            $self->tag('homepage-in-binary-package');
        } else {
            $self->tag('no-homepage-field');
        }

        return;
    }

    return;
}

sub always {
    my ($self) = @_;

    my $processable = $self->processable;

    my $homepage = $processable->unfolded_field('homepage');

    return
      unless defined $homepage;

    my $orig = $processable->field('homepage');

    if ($homepage =~ /^<(?:UR[LI]:)?.*>$/i) {
        $self->tag('superfluous-clutter-in-homepage', $orig);
        $homepage = substr($homepage, 1, length($homepage) - 2);
    }

    require URI;
    my $uri = URI->new($homepage);

    # not an absolute URI or (most likely) an invalid protocol
    $self->tag('bad-homepage', $orig)
      unless $uri->scheme && $uri->scheme =~ /^(?:ftp|https?|gopher)$/;

    foreach my $line ($BAD_HOMEPAGES->all) {
        my ($tag, $re) = split(/\s*~~\s*/, $line);
        $self->tag($tag, $orig) if $homepage =~ m/$re/;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

# fields/uploaders -- lintian check script (rewrite) -*- perl -*-
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

package Lintian::fields::uploaders;

use v5.20;
use warnings;
use utf8;
use autodie;

use Email::Address::XS;
use List::UtilsBy qw(count_by);

use Lintian::Maintainer qw(check_maintainer);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub always {
    my ($self) = @_;

    my $processable = $self->processable;

    my $uploaders = $processable->unfolded_field('uploaders');

    return
      unless defined $uploaders;

    # Note, not expected to hit on uploaders anymore, as dpkg
    # now strips newlines for the .dsc, and the newlines don't
    # hurt in debian/control

    # check for empty field see  #783628
    if($uploaders =~ m/,\s*,/) {
        $self->tag('uploader-name-missing','you have used a double comma');
        $uploaders =~ s/,\s*,/,/g;
    }

    # may now enable #485705 to be solved
    my @uploaders = Email::Address::XS->parse($uploaders);

    my @validated = grep { $_->is_valid } @uploaders;
    $self->tag('uploader', $_->format) for @validated;

    my @invalid = grep { !$_->is_valid } @uploaders;
    $self->tag('malformed-uploaders-field') if @invalid;

    for my $uploader (@validated) {
        my @tags = check_maintainer($uploader->format, 'uploader');
        $self->tag(@{$_}) for @tags;
    }

    my %counts = count_by { $_->format } @validated;
    my @duplicates = grep { $counts{$_} > 1 } keys %counts;
    $self->tag('duplicate-uploader', $_) for @duplicates;

    my $maintainer = $processable->field('maintainer');
    if (defined $maintainer) {

        $self->tag('maintainer-also-in-uploaders')
          if $processable->field('uploaders') =~ m/\Q$maintainer/;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

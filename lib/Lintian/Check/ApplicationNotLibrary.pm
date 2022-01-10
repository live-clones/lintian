# application-not-library -- find applications packaged like a library -*- perl -*-
#
# Copyright © 2014-2015 Axel Beckert <abe@debian.org>
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

package Lintian::Check::ApplicationNotLibrary;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(any);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub installable {
    my ($self) = @_;

    # big exception list for all tags
    return
      # perl itself
      if $self->processable->name =~ /^perl(?:-base)?$/
      # ruby itself
      || $self->processable->name =~ /^ruby[\d.]*$/
      # python itself
      || $self->processable->name =~ /^python[\d.]*(?:-dev|-minimal)?$/
      # cpan related tools
      || $self->processable->name =~ /^cpan/
      # perl module tools
      || $self->processable->name =~ /^libmodule-.*-perl$/
      # perl debugging tools
      || $self->processable->name =~ /^libdevel-.*-perl$/
      # perl-handling tools
      || $self->processable->name =~ /^libperl.*-perl$/
      # perl testing tools
      || $self->processable->name =~ /^libtest-.*-perl$/
      # python packaging stuff
      || $self->processable->name =~ /^python[\d.]*-(?:stdeb|setuptools)$/
      # ruby packaging stuff
      || $self->processable->name =~ /^gem2deb/
      # rendering engine
      || $self->processable->name =~ /^xulrunner/
      # generic helpers
      || $self->processable->name =~ /^lib.*-(?:utils|tools|bin|dev)/
      # whitelist
      || (
        any { $self->processable->name eq $_ }
        qw(

        rake
        bundler
        coderay
        kdelibs-bin
        libapp-options-perl

        ));

    my @programs;
    for my $searched_folder (qw{bin sbin usr/bin usr/sbin usr/games}) {

        my $directory_item
          = $self->processable->installed->lookup("$searched_folder/");
        next
          unless defined $directory_item;

        for my $program_item ($directory_item->children) {

            # ignore debhelper plugins
            next
              if $program_item->basename =~ /^dh_/;

            # ignore library configuration tools
            next
              if $program_item->name =~ /properties$/;

            # ignore library maintenance tools
            next
              if $program_item->name  =~ /update$/;

            push(@programs, $program_item);
        }
    }

    return
      unless @programs;

    # check for library style package names
    if (   $self->processable->name =~ m{^ lib (?:.+) -perl $}x
        || $self->processable->name =~ m{^ruby-}x
        || $self->processable->name =~ m{^python[\d.]*-}x) {

        if ($self->processable->name =~ m{^ libapp (?:.+) -perl $}x) {
            $self->pointed_hint('libapp-perl-package-name', $_->pointer)
              for @programs;

        } else {
            $self->pointed_hint('library-package-name-for-application',
                $_->pointer)
              for @programs;
        }
    }

    my $section = $self->processable->fields->value('Section');

    # oldlibs is ok
    if ($section =~ m{ perl | python | ruby | (?: ^ | / ) libs }x) {

        $self->pointed_hint('application-in-library-section',
            $_->pointer, $section)
          for @programs;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

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

    my $pkg = $self->processable->name;
    my $processable = $self->processable;

    return if # Big exception list for all tags
      $pkg =~ /^perl(?:-base)?$/                    or # perl itself
      $pkg =~ /^ruby[\d.]*$/                        or # ruby itself
      $pkg =~ /^python[\d.]*(?:-dev|-minimal)?$/    or # python itself
      $pkg =~ /^cpan/                               or # cpan related tools
      $pkg =~ /^libmodule-.*-perl$/                 or # perl module tools
      $pkg =~ /^libdevel-.*-perl$/                  or # perl debugging tools
      $pkg =~ /^libperl.*-perl$/                    or # perl-handling tools
      $pkg =~ /^libtest-.*-perl$/                   or # perl testing tools
      $pkg =~ /^python[\d.]*-(?:stdeb|setuptools)$/ or # python packaging stuff
      $pkg =~ /^gem2deb/                            or # ruby packaging stuff
      $pkg =~ /^xulrunner/                          or # rendering engine
      $pkg =~ /^lib.*-(?:utils|tools|bin|dev)/      or # generic helpers
      any { $pkg eq $_ } qw(

      rake
      bundler
      coderay
      kdelibs-bin
      libapp-options-perl

      ); # whitelist

    my @programs = ();
    foreach my $binpath (qw(bin sbin usr/bin usr/sbin usr/games)) {
        my $bindir = $processable->installed->lookup("$binpath/");
        next unless $bindir;

        push(
            @programs,
            grep { !/update$/ }       # ignore library maintenance tools
              grep { !/properties$/ } # ignore library configuration tools
              map { $_->name; }
              grep { $_->basename !~ /^dh_/ } # ignore debhelper plugins
              $bindir->children
        );
    }

    return unless @programs;

    # Check for library style package names
    if ($pkg =~ /^lib(?:.+)-perl$|^ruby-|^python[\d.]*-/) {
        if ($pkg =~ /^libapp(?:.+)-perl$/) {
            $self->hint('libapp-perl-package-name', @programs);
        } else {
            $self->hint('library-package-name-for-application', @programs);
        }
    }

    # Check for wrong section
    my $section = $processable->fields->value('Section');
    if ($section =~ /perl|python|ruby|(?:^|\/)libs/) { # oldlibs is ok
        $self->hint('application-in-library-section', "$section", @programs);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

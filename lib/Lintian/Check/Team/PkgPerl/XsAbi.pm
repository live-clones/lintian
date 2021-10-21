# team/pkg-perl/xs-abi -- lintian check script for XS target directory -*- perl -*-
#
# Copyright © 2014 Damyan Ivanov <dmn@debian.org>
# Copyright © 2014 Axel Beckert <abe@debian.org>
# Copyright © 2020 Felix Lechner
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

package Lintian::Check::Team::PkgPerl::XsAbi;

use v5.20;
use warnings;
use utf8;

use Dpkg::Version;

use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

has relies_on_modern_api => (
    is => 'rw',
    lazy => 1,
    coerce => sub { my ($boolean) = @_; return ($boolean // 0); },
    default => sub {
        my ($self) = @_;

        return 0
          if $self->processable->fields->value('Architecture') eq 'all';

        my $depends = $self->processable->relation('strong');

        my $api_version = $depends->visit(
            sub {
                my ($prerequisite) = @_;

                if ($prerequisite =~ /^perlapi-(\d[\d.]*)$/) {
                    return $1;
                }

                return;
            },
            Lintian::Relation::VISIT_OR_CLAUSE_FULL
              | Lintian::Relation::VISIT_STOP_FIRST_MATCH
        );

        return 0
          unless defined $api_version;

        return 1
          if version_compare_relation($api_version, REL_GE, '5.19.11');

        return 0;
    });

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      unless $item->is_file;

    return
      unless $item->name =~ m{^usr/lib/perl5/};

    $self->hint('legacy-vendorarch-directory', $item->name)
      if $self->relies_on_modern_api;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

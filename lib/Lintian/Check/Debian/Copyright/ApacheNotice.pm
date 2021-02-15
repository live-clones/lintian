# debian/copyright/apache-notice -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz
# Copyright © 2011 Jakub Wilk
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

package Lintian::Check::Debian::Copyright::ApacheNotice;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SPACE => q{ };

sub source {
    my ($self) = @_;

    my $debian_dir = $self->processable->patched->resolve_path('debian/');
    return
      unless defined $debian_dir;

    my @installables = $self->processable->debian_control->installables;
    my @additional = map { $_ . '.copyright' } @installables;

    my @candidates = ('copyright', @additional);
    my @files = grep { defined } map { $debian_dir->child($_) } @candidates;

    # another check complains about legacy encoding, if needed
    my @valid_utf8 = grep { $_->is_valid_utf8 } @files;

    $self->check_apache_notice_files($_)for @valid_utf8;

    return;
}

sub check_apache_notice_files {
    my ($self, $file) = @_;

    my $contents = $file->decoded_utf8;
    return
      unless $contents =~ /apache[-\s]+2\./i;

    my @notice_files = grep {
              $_->basename =~ /^NOTICE(\.txt)?$/
          and $_->is_open_ok
          and $_->bytes =~ /apache/i
    } @{$self->processable->patched->sorted_list};
    return
      unless @notice_files;

    my @binaries = $self->group->get_processables('binary');
    return
      unless @binaries;

    for my $binary (@binaries) {

        # look at all path names in the package
        my @names = map { $_->name } @{$binary->installed->sorted_list};

        # and also those shipped in jars
        my @jars = grep { scalar keys %{$_->java_info} }
          @{$binary->installed->sorted_list};
        push(@names, keys %{$_->java_info->{files}})for @jars;

        return
          if any { m{/NOTICE(\.txt)?(\.gz)?$} } @names;
    }

    $self->hint('missing-notice-file-for-apache-license',
        join($SPACE, @notice_files));

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

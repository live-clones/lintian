#
# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2013 Niels Thykier
# Copyright © 2017 Chris Lamb <lamby@debian.org>
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

package Lintian::Version;

use v5.20;
use warnings;
use utf8;

our @EXPORT_OK = (qw(
      guess_version
));

use Exporter qw(import);

use Const::Fast;
use Unicode::UTF8 qw(decode_utf8);

use Lintian::IPC::Run3 qw(safe_qx);
use Lintian::Util qw(version_from_changelog);

const my $EMPTY => q{};

=head1 NAME

Lintian::Version - routines to determine Lintian version

=head1 SYNOPSIS

 use Lintian::Version;

=head1 DESCRIPTION

Lintian::Version can help guess the current Lintian version.

=head1 INSTANCE METHODS

=over 4

=item guess_version

=cut

sub guess_version {
    my ($lintian_base) = @_;

    my $guess = version_from_git($lintian_base);
    $guess ||= version_from_changelog($lintian_base);

    return $guess;
}

=item version_from_git

=cut

sub version_from_git {
    my ($source_path) = @_;

    my $git_path = "$source_path/.git";

    return $EMPTY
      unless -d $git_path;

    my $describe
      = decode_utf8(safe_qx('git', "--git-dir=$git_path", 'describe'));
    chomp $describe;

    my ($guess, $step, $commit) = split(/-/, $describe);
    $guess =~ s/ [.] 0 $/.$step/sx;

    return ($guess // $EMPTY);
}

=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

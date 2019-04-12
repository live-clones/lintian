# Copyright © 1998 Richard Braakman
# Copyright © 2008 Frank Lichtenheld
# Copyright © 2008, 2009 Russ Allbery
# Copyright © 2018 Felix Lechner
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
# MA 02110-1301, USA

package Test::Lintian::Helper;

=head1 NAME

Test::Lintian::Helper -- Helper functions for various testing parts

=head1 SYNOPSIS

  use Test::Lintian::Helper qw(get_latest_policy);
  my $policy_version = get_latest_policy();

=head1 DESCRIPTION

Helper functions for preparing and running Lintian tests.

=cut

use strict;
use warnings;
use autodie;
use v5.10;

use Exporter qw(import);

BEGIN {
    our @EXPORT_OK = qw(
      cache_dpkg_architecture_values
      get_latest_policy
      get_recommended_debhelper_version
      get_required_debhelper_version
      copy_dir_contents
      rfc822date
    );
}

use Capture::Tiny qw(capture);
use Carp;
use File::Spec::Functions qw(abs2rel rel2abs);
use File::Path qw(remove_tree);
use Path::Tiny;
use POSIX qw(locale_h strftime);

use Lintian::Data;
use Lintian::Deb822Parser qw(read_dpkg_control);
use Lintian::Profile;

=head1 FUNCTIONS

=over 4

=item cache_dpkg_architecture_values()

Ensures that the output from dpkg-architecture has been cached.

=cut

sub cache_dpkg_architecture_values {
    open(my $fd, '-|', 'dpkg-architecture')
      or die('dpkg-architecture failed');
    while (my $line = <$fd>) {
        chomp($line);
        my ($k, $v) = split(/=/, $line, 2);
        $ENV{$k} = $v;
    }
    close($fd);
    return;
}

=item get_latest_policy()

Returns a list with two elements. The first is the most recent version
of the Debian policy. The second is its effective date.

=cut

sub get_latest_policy {
    my $profile = Lintian::Profile->new(undef, [$ENV{'LINTIAN_ROOT'}]);
    Lintian::Data->set_vendor($profile);

    my $STANDARDS
      = Lintian::Data->new('standards-version/release-dates', qr/\s+/o);
    my @STANDARDS = reverse sort { $a->[1] <=> $b->[1] }
      map { [$_, $STANDARDS->value($_)] } $STANDARDS->all;

    my $version = $STANDARDS[0][0]
      // die 'Could not get latest policy version.';
    my $epoch = $STANDARDS[0][1]// die 'Could not get latest policy date.';

    return ($version, $epoch);
}

=item get_recommended_debhelper_version()

Returns the version of debhelper recommended in 'debhelper/compat-level'
via Lintian::Data, relative to the established LINTIAN_ROOT.

=cut

sub get_recommended_debhelper_version {
    my $profile = Lintian::Profile->new(undef, [$ENV{'LINTIAN_ROOT'}]);
    Lintian::Data->set_vendor($profile);

    my $compat_level= Lintian::Data->new('debhelper/compat-level', qr/=/);

    return $compat_level->value('recommended');
}

=item get_required_debhelper_version()

Returns the version of debhelper required in the file 'debian/control'
relative to the established LINTIAN_ROOT. The return value is the exact
string, which can include characters like a tilde.

=cut

sub get_required_debhelper_version {
    my $controlfile = "$ENV{'LINTIAN_ROOT'}/debian/control";
    die 'Cannot get latest version of debhelper from debian/control'
      unless -f $controlfile;

    my @paragraphs = read_dpkg_control($controlfile);
    die "$controlfile does not have even one paragraph"
      if (scalar(@paragraphs) < 1);

    my @builddeps = split(/,/, $paragraphs[0]->{'build-depends'});
    chomp @builddeps;
    my $version;
    for my $builddep (@builddeps) {
        ($version) = $builddep =~ /debhelper\s\(>=\s([^\)]+)\)/;
        last if defined $version;
    }
    die 'Lintian does not depend on debhelper.' unless $version;

    return $version;
}

=item copy_dir_contents(SRC_DIR, TARGET_DIR)

Populates TARGET_DIR with files/dirs from SRC_DIR, preserving all attributes but
dereferencing links. For an empty directory, no dummy file is required.

=cut

sub copy_dir_contents {
    my ($source, $destination) = @_;

    # 'cp -r' cannot overwrite directories with files or vice versa
    my @paths = File::Find::Rule->in($source);
    foreach my $path (@paths) {

        my $relative = abs2rel($path, $source);
        my $prospective = rel2abs($relative, $destination);

        # recursively delete directories to be replaced by a file
        remove_tree($prospective)
          if -d $prospective && -f $path;

        # remove files to be replaced by a directory
        unlink($prospective)
          if -f $prospective && -d $path;
    }

    # 'cp -r' with a dot will error without files present
    if (scalar path($source)->children) {

        system('cp', '-rp', "$source/.", '-t', $destination)== 0
          or croak("Could not copy $source to $destination: $!");
    }
    return 1;
}

=item rfc822date(EPOCH)

Returns a string with the date and time described by EPOCH, formatted
according to RFC822.

=cut

sub rfc822date {
    my ($epoch) = @_;

    my $old_locale = setlocale(LC_TIME, 'C');
    my $datestring = strftime('%a, %d %b %Y %H:%M:%S %z', localtime($epoch));
    setlocale(LC_TIME, $old_locale);

    return $datestring;
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

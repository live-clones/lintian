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

use v5.20;
use warnings;
use utf8;

use Exporter qw(import);

BEGIN {
    our @EXPORT_OK = qw(
      cache_dpkg_architecture_values
      get_latest_policy
      get_recommended_debhelper_version
      copy_dir_contents
      rfc822date
    );
}

use Carp;
use File::Spec::Functions qw(abs2rel rel2abs);
use File::Path qw(remove_tree);
use Path::Tiny;
use POSIX qw(locale_h strftime);
use Unicode::UTF8 qw(encode_utf8 decode_utf8);

use Lintian::IPC::Run3 qw(safe_qx);
use Lintian::Profile;

=head1 FUNCTIONS

=over 4

=item cache_dpkg_architecture_values()

Ensures that the output from dpkg-architecture has been cached.

=cut

sub cache_dpkg_architecture_values {

    my $output = decode_utf8(safe_qx('dpkg-architecture'));

    die encode_utf8('dpkg-architecture failed')
      if $?;

    $output = decode_utf8($output)
      if length $output;

    my @lines = split(/\n/, $output);

    for my $line (@lines) {
        my ($k, $v) = split(/=/, $line, 2);
        $ENV{$k} = $v;
    }

    return;
}

=item get_latest_policy()

Returns a list with two elements. The first is the most recent version
of the Debian policy. The second is its effective date.

=cut

sub get_latest_policy {
    my $profile = Lintian::Profile->new;
    $profile->load(undef, undef, 0);

    my $releases = $profile->policy_releases;

    my $version = $releases->latest_version;
    die encode_utf8('Could not get latest policy version.')
      unless defined $version;
    my $epoch = $releases->epoch($version);
    die encode_utf8('Could not get latest policy date.')
      unless defined $epoch;

    return ($version, $epoch);
}

=item get_recommended_debhelper_version()

Returns the version of debhelper recommended in 'debhelper/compat-level'
via Lintian::Data, relative to the established LINTIAN_BASE.

=cut

sub get_recommended_debhelper_version {
    my $profile = Lintian::Profile->new;
    $profile->load(undef, undef, 0);

    my $compat_level = $profile->debhelper_levels;

    return $compat_level->value('recommended');
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
          if -d $prospective && -e $path && !-d _;

        # remove files to be replaced by a directory
        if (-e $prospective && !-d _ && -d $path) {
            unlink($prospective)
              or die encode_utf8("Cannot unlink $prospective");
        }
    }

    # 'cp -r' with a dot will error without files present
    if (scalar path($source)->children) {

        system('cp', '-rp', "$source/.", '-t', $destination)== 0
          or croak encode_utf8("Could not copy $source to $destination: $!");
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

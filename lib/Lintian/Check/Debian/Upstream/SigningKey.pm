# debian/upstream/signing-key -- lintian check script -*- perl -*-

# Copyright © 2018 Felix Lechner
#
# This program is free software.  It is distributed under the terms of
# the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any
# later version.
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

package Lintian::Check::Debian::Upstream::SigningKey;

use v5.20;
use warnings;
use utf8;

use File::Temp;
use List::Util qw(pairs);
use Unicode::UTF8 qw(decode_utf8);

use Lintian::IPC::Run3 qw(safe_qx);

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $processable = $self->processable;

    my $SIGNING_KEY_FILENAMES
      = $self->profile->load_data('common/signing-key-filenames');

    # Check all possible locations for signing keys
    my %key_locations;
    for my $key_name ($SIGNING_KEY_FILENAMES->all) {
        my $path = $processable->patched->resolve_path("debian/$key_name");
        $key_locations{$key_name} = $path->unpacked_path
          if $path && $path->is_file;
    }

    # Check if more than one signing key is present
    $self->hint('public-upstream-keys-in-multiple-locations',
        (sort keys %key_locations))
      if scalar keys %key_locations > 1;

    # Go through signing keys and run checks for each
    for my $key_name (sort keys %key_locations) {

        # native packages should not have such keys
        if ($processable->native) {
            $self->hint('public-upstream-key-in-native-package', $key_name);
            next;
        }

        # set up a temporary directory for gpg
        my $tempdir = File::Temp->newdir();

        # get keys packets from gpg
        my @command = (
            'gpg', '--homedir',
            $tempdir, '--batch',
            '--attribute-fd', '1',
            '--status-fd', '2',
            '--with-colons', '--list-packets',
            $key_locations{$key_name});
        my $bytes = safe_qx(@command);

        if ($?) {
            $self->hint('public-upstream-key-unusable',
                $key_name,'cannot be processed');
            next;
        }

        my $output = decode_utf8($bytes);

        # remove comments
        $output =~ s/^#[^\n]*$//mg;

        # split into separate keys
        my @keys = split(/^:public key packet:.*$/m, $output);

        # discard leading information
        shift @keys;

        unless (scalar @keys) {
            $self->hint('public-upstream-key-unusable',
                $key_name,'contains no keys');
            next;
        }

        for my $key (@keys) {

            # parse each key into separate packets
            my ($public_key, @pieces) = split(/^(:.+)$/m, $key);
            my @packets = pairs @pieces;

            # require at least one packet
            unless (length $public_key) {
                $self->hint('public-upstream-key-unusable',
                    $key_name,'has no public key');
                next;
            }

            # look for key identifier
            unless ($public_key =~ qr/^\s*keyid:\s+(\S+)$/m) {
                $self->hint('public-upstream-key-unusable',
                    $key_name, 'has no keyid');
                next;
            }
            my $keyid = $1;

            # look for third-party signatures
            my @thirdparty;
            for my $packet (@packets) {

                my $header = $packet->[0];
                if ($header =~ qr/^:signature packet: algo \d+, keyid (\S*)$/){

                    my $signatory = $1;
                    push(@thirdparty, $signatory)
                      unless $signatory eq $keyid;
                }
            }

            # signatures by parties other than self
            my $extrasignatures = scalar @thirdparty;

            # export-minimal strips such signatures
            $self->hint('public-upstream-key-not-minimal',
                $key_name,
                "has $extrasignatures extra signature(s) for keyid $keyid")
              if $extrasignatures;
        }
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

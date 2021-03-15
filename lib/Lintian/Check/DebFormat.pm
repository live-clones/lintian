# deb-format -- lintian check script -*- perl -*-

# Copyright © 2009 Russ Allbery
# Copyright © 2018 Chris Lamb <lamby@debian.org>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::Check::DebFormat;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use IPC::Run3;
use List::SomeUtils qw(first_index none);
use Path::Tiny;
use Unicode::UTF8 qw(decode_utf8);

use Lintian::IPC::Run3 qw(safe_qx);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $SPACE => q{ };

const my $MINIMUM_DEB_ARCHIVE_MEMBERS => 3;
const my $INDEX_NOT_FOUND => -1;

sub installable {
    my ($self) = @_;

    my $EXTRA_MEMBERS = $self->profile->load_data('deb-format/extra-members');

    my $deb_path = $self->processable->path;

    # set to one when something is so bad that we can't continue
    my $failed;

    my @command = ('ar', 't', $deb_path);

    my $stdout;
    my $stderr;

    run3(\@command, \undef, \$stdout, \$stderr);

    unless ($?) {
        my @members = split(/\n/, $stdout);
        my $count = scalar(@members);
        my ($ctrl_member, $data_member);

        if ($count < $MINIMUM_DEB_ARCHIVE_MEMBERS) {
            $self->hint('malformed-deb-archive',
"found only $count members instead of $MINIMUM_DEB_ARCHIVE_MEMBERS"
            );

        } elsif ($members[0] ne 'debian-binary') {
            $self->hint('malformed-deb-archive',
                "first member $members[0] not debian-binary");

        } elsif (
            $count == $MINIMUM_DEB_ARCHIVE_MEMBERS && none {
                substr($_, 0, 1) eq '_';
            }
            @members
        ) {
            # Fairly common case - if there are only 3 members without
            # "_", we can trivially determine their (expected)
            # positions.  We only use this case when there are no
            # "extra" members, because they can trigger more tags
            # (see below)
            (undef, $ctrl_member, $data_member) = @members;

        } else {
            my $ctrl_index
              = first_index { substr($_, 0, 1) ne '_' } @members[1..$#members];
            my $data_index;

            if ($ctrl_index != $INDEX_NOT_FOUND) {
                # Since we searched only a sublist of @members, we have to
                # add 1 to $ctrl_index
                $ctrl_index++;
                $ctrl_member = $members[$ctrl_index];
                $data_index = first_index { substr($_, 0, 1) ne '_' }
                @members[$ctrl_index+1..$#members];
                if ($data_index != $INDEX_NOT_FOUND) {
                    # Since we searched only a sublist of @members, we
                    # have to adjust $data_index
                    $data_index += $ctrl_index + 1;
                    $data_member = $members[$data_index];
                }
            }

            # Extra members
            # NB: We deliberately do not allow _extra member,
            # since various tools seems to be unable to cope
            # with them particularly dak
            # see https://wiki.debian.org/Teams/Dpkg/DebSupport
            for my $i (1..$#members) {
                my $member = $members[$i];
                my $actual_index = $i;
                my ($expected, $text);
                next if $i == $ctrl_index or $i == $data_index;
                $expected = $EXTRA_MEMBERS->value($member);
                if (defined($expected)) {
                    next if $expected eq 'ANYWHERE';
                    next if $expected == $actual_index;
                    $text = "expected at position $expected, but appeared";
                } elsif (substr($member,0,1) eq '_') {
                    $text = 'unexpected _member';
                } else {
                    $text = 'unexpected member';
                }
                $self->hint('misplaced-extra-member-in-deb',
                    "$member ($text at position $actual_index)");
            }
        }

        if (not defined($ctrl_member)) {
            # Somehow I doubt we will ever get this far without a control
            # file... :)
            $self->hint('malformed-deb-archive', 'Missing control.tar member');
            $failed = 1;
        } else {
            if (
                $ctrl_member !~ m{\A
                     control\.tar(?:\.(?:gz|xz))?  \Z}xsm
            ) {
                $self->hint(
                    'malformed-deb-archive',
                    join($SPACE,
                        "second (official) member $ctrl_member",
                        'not control.tar.(gz|xz)'));
                $failed = 1;
            } elsif ($ctrl_member eq 'control.tar') {
                $self->hint('uses-no-compression-for-control-tarball');
            }
            $self->hint('control-tarball-compression-format',
                $ctrl_member =~ s/^control\.tar\.?//r || '(none)');
        }

        if (not defined($data_member)) {
            # Somehow I doubt we will ever get this far without a data
            # member (i.e. I suspect unpacked and index will fail), but
            # mah
            $self->hint('malformed-deb-archive', 'Missing data.tar member');
            $failed = 1;
        } else {
            if (
                $data_member !~ m{\A
                     data\.tar(?:\.(?:gz|bz2|xz|lzma))?  \Z}xsm
            ) {
                # wasn't okay after all
                $self->hint(
                    'malformed-deb-archive',
                    join($SPACE,
                        "third (official) member $data_member",
                        'not data.tar.(gz|xz|bz2|lzma)'));
                $failed = 1;
            } elsif ($self->processable->type eq 'udeb'
                && $data_member !~ m/^data\.tar\.[gx]z$/) {
                $self->hint(
                    'udeb-uses-unsupported-compression-for-data-tarball');
            } elsif ($data_member eq 'data.tar.lzma') {
                $self->hint('uses-deprecated-compression-for-data-tarball',
                    'lzma');
                # Ubuntu's archive allows lzma packages.
                $self->hint('lzma-deb-archive');
            } elsif ($data_member eq 'data.tar.bz2') {
                $self->hint('uses-deprecated-compression-for-data-tarball',
                    'bzip2');
            } elsif ($data_member eq 'data.tar') {
                $self->hint('uses-no-compression-for-data-tarball');
            }
            $self->hint('data-tarball-compression-format',
                $data_member =~ s/^data\.tar\.?//r || '(none)');
        }
    } else {
        # unpack will probably fail so we'll never get here, but may as well be
        # complete just in case.
        $stderr =~ s/\n.*//s;
        $stderr =~ s/^ar:\s*//;
        $stderr =~ s/^deb:\s*//;
        $self->hint('malformed-deb-archive', "ar error: $stderr");
    }

    # Check the debian-binary version number.  We probably won't get
    # here because dpkg-deb will decline to unpack the deb, but be
    # thorough just in case.  We may eventually have a case where dpkg
    # supports a newer format but it's not permitted in the archive
    # yet.
    if (not defined($failed)) {
        my $bytes = safe_qx('ar', 'p', $deb_path, 'debian-binary');
        if ($? != 0) {
            $self->hint('malformed-deb-archive',
                'cannot read debian-binary member');
        } else {
            my $output = decode_utf8($bytes);
            if ($output !~ /^2\.\d+\n/) {
                my ($version) = split(m/\n/, $output);
                $self->hint('malformed-deb-archive',
                    "version $version not 2.0");
            }
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

# Copyright (C) 2026 Nilesh Patra
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

package Lintian::Processable::Source::CompatLevel;

use v5.20;
use warnings;
use utf8;

use Path::Tiny;
use Cwd qw(getcwd);
use IPC::Run3 qw(run3);
use JSON::MaybeXS qw(decode_json);
use Unicode::UTF8 qw(encode_utf8);
use Const::Fast;

use Moo::Role;
use namespace::clean;

const my $WAIT_STATUS_SHIFT => 8;

=head1 NAME

Lintian::Processable::Source::CompatLevel - Lintian interface to get debhelper compat level

=head1 SYNOPSIS

    use Lintian::Processable;

=head1 DESCRIPTION

Lintian::Processable::Source::CompatLevel provides an interface to get debhelper compat levels and sources for compat

=head1 INSTANCE METHODS

=over 4

=item compat_level

Returns the compat level and the source for compat

=cut

has compat_level => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $savedir = getcwd;
        my $droot = $self->patched->basedir;
        my @dh_assistant_cmd= qw{dh_assistant active-compat-level};
        my $dh_assistant_output;
        my $debhelper_level;
        my $debhelper_compat_source;

        chdir($droot)
          or die encode_utf8('Cannot change to directory ' . $droot);

        run3(\@dh_assistant_cmd, undef, \$dh_assistant_output,undef);

        my $exitcode = $?;
        my $status = ($exitcode >> $WAIT_STATUS_SHIFT);

        chdir($savedir)
          or die encode_utf8("Cannot change to directory $savedir");

        if ($status == 0) {
            my $compat_data = decode_json($dh_assistant_output);
            $debhelper_level = $compat_data->{'declared-compat-level'};
            $debhelper_compat_source
              = $compat_data->{'declared-compat-level-source'};
        }

        return {
            level  => $debhelper_level,
            source => $debhelper_compat_source,
        };
    }
);

=back

=head1 AUTHOR

Originally written by Nilesh Patra <nilesh@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et


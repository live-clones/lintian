# -*- perl -*- Lintian::Processable::Diffstat -- access to collected diffstat data
#
# Copyright © 1998 Richard Braakman
# Copyright © 2019-2020 Felix Lechner
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

package Lintian::Processable::Diffstat;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use IPC::Run3;
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8 decode_utf8);

use Moo::Role;
use namespace::clean;

const my $COLON => q{:};
const my $UNDERSCORE => q{_};
const my $NEWLINE => qq{\n};

const my $OPEN_PIPE => q{-|};
const my $WAIT_STATUS_SHIFT => 8;

=head1 NAME

Lintian::Processable::Diffstat - access to collected diffstat data

=head1 SYNOPSIS

    use Lintian::Processable;

=head1 DESCRIPTION

Lintian::Processable::Diffstat provides an interface to diffstat data.

=head1 INSTANCE METHODS

=over 4

=item diffstat

Returns the path to diffstat output run on the Debian packaging diff
(a.k.a. the "diff.gz") for 1.0 non-native packages.  For source
packages without a "diff.gz" component, this returns the path to an
empty file (this may be a device like /dev/null).

=cut

has diffstat => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $noepoch = $self->fields->value('Version');

        # strip epoch
        $noepoch =~ s/^\d://;

        # look for a format 1.0 diff.gz near the input file
        my $diffname = $self->name . $UNDERSCORE . $noepoch . '.diff.gz';
        return {}
          unless exists $self->files->{$diffname};

        my $diffpath = path($self->path)->parent->child($diffname)->stringify;
        return {}
          unless -e $diffpath;

        my @gunzip_command = ('gunzip', '--stdout', $diffpath);
        my $gunzip_pid = open(my $from_gunzip, $OPEN_PIPE, @gunzip_command)
          or die encode_utf8("Cannot run @gunzip_command: $!");

        my $stdout;
        my $stderr;
        my @diffstat_command = qw(diffstat -p1);
        run3(\@diffstat_command, $from_gunzip, \$stdout, \$stderr);
        my $status = ($? >> $WAIT_STATUS_SHIFT);

        $stdout = decode_utf8($stdout)
          if length $stdout;
        $stderr = decode_utf8($stderr)
          if length $stderr;

        if ($status) {

            my $message= "Non-zero status $status from @diffstat_command";
            $message .= $COLON . $NEWLINE . $stderr
              if length $stderr;

            die encode_utf8($message);
        }

        close $from_gunzip
          or
          warn encode_utf8("close failed for handle from @gunzip_command: $!");

        waitpid($gunzip_pid, 0);

        # remove summary in last line
        chomp $stdout;
        $stdout =~ s/.*\Z//;

        my %diffstat;

        my @lines = split(/\n/, $stdout);
        for my $line (@lines) {

            next
              unless $line =~ s/\|\s*([^|]*)\s*$//;

            my $stats = $1;
            my $file = $line;

            # trim both ends
            $file =~ s/^\s+|\s+$//g;

            die encode_utf8("syntax error in diffstat file: $line")
              unless length $file;

            $diffstat{$file} = $stats;
        }

        return \%diffstat;
    });

1;

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1)

=cut

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

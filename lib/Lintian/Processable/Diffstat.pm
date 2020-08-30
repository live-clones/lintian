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
use autodie;

use IPC::Run3;
use Path::Tiny;

use constant EMPTY => q{};
use constant COLON => q{:};
use constant UNDERSCORE => q{_};
use constant NEWLINE => qq{\n};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Diffstat - access to collected diffstat data

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Processable::Diffstat provides an interface to diffstat data.

=head1 INSTANCE METHODS

=over 4

=item add_diffstat

=cut

sub add_diffstat {
    my ($self) = @_;

    my $noepoch = $self->fields->value('Version');

    # strip epoch
    $noepoch =~ s/^\d://;

    my $diffname = $self->name . UNDERSCORE . $noepoch . '.diff.gz';
    my $diffpath = path($self->basedir)->child($diffname)->stringify;
    return
      unless -f $diffpath;

    my @gunzip_command = ('gunzip', '--stdout', $diffpath);
    my $gunzip_pid = open(my $from_gunzip, '-|', @gunzip_command)
      or die "Cannot run @gunzip_command: $!";

    my $stdout;
    my $stderr;
    my @diffstat_command = ('diffstat',  '-p1');
    run3(\@diffstat_command, $from_gunzip, \$stdout, \$stderr);

    my $status = ($? >> 8);
    if ($status) {

        my $message= "Non-zero status $status from @diffstat_command";
        $message .= COLON . NEWLINE . $stderr
          if length $stderr;

        die $message;
    }

    close $from_gunzip
      or warn "close failed for handle from @gunzip_command: $!";

    waitpid($gunzip_pid, 0);

    # remove summary in last line
    chomp $stdout;
    $stdout =~ s/.*\Z//;

    # copy all lines except the last
    path($self->basedir)->child('diffstat')->spew($stdout);

    return;
}

=item diffstat

Returns the path to diffstat output run on the Debian packaging diff
(a.k.a. the "diff.gz") for 1.0 non-native packages.  For source
packages without a "diff.gz" component, this returns the path to an
empty file (this may be a device like /dev/null).

=cut

sub diffstat {
    my ($self) = @_;

    my $diffstat = path($self->basedir)->child('diffstat')->stringify;

    $diffstat = '/dev/null'
      unless -e $diffstat;

    return $diffstat;
}

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

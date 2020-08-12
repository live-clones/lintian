# -*- perl -*-
#
# Lintian::Processable::Source::Diffstat -- lintian collection script for source packages

# Copyright © 1998 Richard Braakman
# Copyright © 2019-2020 Felix Lechner
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

# This could be written more easily in shell script, but I'm trying
# to keep everything as perl to cut down on the number of processes
# that need to be started in a lintian scan.  Eventually all the
# perl code will be perl modules, so only one perl interpreter
# need be started.

package Lintian::Processable::Source::Diffstat;

use v5.20;
use warnings;
use utf8;
use autodie;

use IPC::Run3;
use Path::Tiny;

use Lintian::Deb822::File;

use constant COLON => q{:};
use constant UNDERSCORE => q{_};
use constant NEWLINE => qq{\n};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Source::Diffstat - collect diffstat information

=head1 SYNOPSIS

    Lintian::Processable::Source::Diffstat::collect(undef, undef, undef);

=head1 DESCRIPTION

Lintian::Processable::Source::Diffstat collects diffstat information.

=head1 INSTANCE METHODS

=over 4

=item add_diffstat

=cut

sub add_diffstat {
    my ($self) = @_;

    my $dscpath = path($self->groupdir)->child('dsc')->stringify;
    die 'diffstat invoked with wrong dir argument'
      unless -f $dscpath;

    my $patchpath = path($self->groupdir)->child('debian-patch')->stringify;
    unlink($patchpath)
      if -e $patchpath || -l $patchpath;

    my $deb822 = Lintian::Deb822::File->new;

    my @sections;
    eval { @sections = $deb822->read_file($dscpath) };
    return
      if length $@;

    my $fields = $sections[0];

    my $noepoch = $fields->value('Version');

    # strip epoch
    $noepoch =~ s/^\d://;

    my $diffname = $self->name . UNDERSCORE . $noepoch . '.diff.gz';
    my $diffpath = path($self->groupdir)->child($diffname)->stringify;
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
    path($self->groupdir)->child('diffstat')->spew($stdout);

    return;
}

=back

=head1 AUTHOR

Originally written by Richard Braakman <dark@xs4all.nl> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

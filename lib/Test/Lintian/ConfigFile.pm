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

package Test::Lintian::ConfigFile;

=head1 NAME

Test::Lintian::ConfigFile -- generic helper routines for colon-delimited configuration files

=head1 SYNOPSIS

use Test::Lintian::ConfigFile qw(read_config);
my $desc = read_config('t/suite/test/desc');

=head1 DESCRIPTION

Routines for dealing with colon-delimited configuration files.

=cut

use strict;
use warnings;
use autodie;

use Exporter qw(import);

BEGIN {
    our @EXPORT_OK = qw(
      read_config
      write_config
      read_field_from_file
    );
}

use Carp;
use List::MoreUtils qw(any);
use Path::Tiny;

use Lintian::Util qw(read_dpkg_control);

use constant NEWLINE => qq{\n};
use constant SPACE => q{ };

=head1 FUNCTIONS

=over 4

=item read_config(PATH, HASHREF)

Reads the configuration file located at PATH into a hash and
returns it. When also passed a HASHREF, will fill that instead.

=cut

sub read_config {
    my ($configpath, $hashref) = @_;

    croak "Cannot find file $configpath."
      unless -f $configpath;

    my @paragraphs = read_dpkg_control($configpath);
    croak "$configpath does not have exactly one paragraph"
      if (scalar(@paragraphs) != 1);

    my $config;

    # use existing hash ref if supplied
    $config = $hashref if defined $hashref;

    # insert values into our hash ref
    foreach my $key (keys %{$paragraphs[0]}) {
        my $underscored = $key;
        $underscored =~ s/-/_/g;
        $config->{$underscored} = $paragraphs[0]->{$key};

        # unwrap continuation lines
        $config->{$underscored} =~ s/\n/ /g;

        # trim both ends
        $config->{$underscored} =~ s/^\s+|\s+$//g;

        # reduce multiple spaces to one
        $config->{$underscored} =~ s/\s+/ /g;
    }

    return $config;
}

=back

=cut

1;

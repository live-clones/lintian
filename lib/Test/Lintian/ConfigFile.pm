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
my $desc = read_config('t/tags/testname/desc');

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

use Lintian::Deb822Parser qw(read_dpkg_control);

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

=item write_config(TEST_CASE, PATH)

Write the config described by hash reference TEST_CASE to the file named PATH.

=cut

sub write_config {
    my ($testcase, $path) = @_;

    my $desc = path($path);
    $desc->remove;

    my @lines;
    foreach my $key (sort keys %{$testcase}) {

        next unless defined $testcase->{$key};

        my $label = $key;
        $label =~ s/_/-/g;
        $label =~ s/\b(\w)/\U$1/g;

        my @elements = split(/ /, $testcase->{$key});
        unless (
            scalar @elements > 1 && any { $_ eq $label }
            ('Test-For', 'Test-Against')
        ) {
            push(@lines, "$label: $testcase->{$key}" . NEWLINE);
            next;
        }

        push(@lines, "$label:" . NEWLINE);
        push(@lines, SPACE . $_ . NEWLINE)for @elements;
    }

    $desc->append_utf8(@lines);

    return;
}

=item read_field_from_file(FIELD, FILE)

Returns the list of lines from file FILE which start with the string FIELD
followed by a colon. The string FIELD and the colon are removed from each
line.

=cut

sub read_field_from_file {
    my ($requested, $path) = @_;

    croak "Could not find file $path." unless -f $path;
    my @lines = path($path)->lines_utf8;

    my @values;
    foreach my $line (@lines) {
        next if $line =~ /^\s+$/;
        next if $line =~ /^\s*#/;
        my ($field, $value) = $line =~ /\s*([^\s:]+):\s+(.*)$/;
        die "Poorly formatted line in $path." unless length $field;
        if($field eq $requested) {
            push(@values, $value);
        }
    }
    return @values;
}

=back

=cut

1;

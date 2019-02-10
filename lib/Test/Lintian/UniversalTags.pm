# Copyright © 2019 Felix Lechner
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

package Test::Lintian::UniversalTags;

=head1 NAME

Test::Lintian::UniversalTags -- routines for universal tag files

=head1 SYNOPSIS

  use Test::Lintian::UniversalTags qw(get_tagnames);

  my $filepath = "path to a universal tag file";
  my @tags = get_tagnames($filepath);

=head1 DESCRIPTION

Helper routines to deal with universal tag files. This is an abstract
format that has the minimum information found in all Lintian output
formats.

=cut

use strict;
use warnings;
use autodie;
use v5.10;

use Exporter qw(import);

BEGIN {
    our @EXPORT_OK = qw(
      get_tagnames
    );
}

use List::Util qw(all);
use Path::Tiny;
use Text::CSV;

use Lintian::Profile;

use constant SPACE => q{ };
use constant EMPTY => q{};
use constant NEWLINE => qq{\n};

=head1 FUNCTIONS

=over 4

=item logged_runner(RUN_PATH)

Starts the generic test runner for the test located in RUN_PATH
and logs the output.

=cut

sub get_tagnames {
    my ($path) = @_;

    my @names;

    my $csv = Text::CSV->new({ sep_char => '|' });

    my @lines = path($path)->lines_utf8({ chomp => 1 });
    foreach my $line (@lines) {

        my $status = $csv->parse($line);
        die "Cannot parse line $line: " . $csv->error_diag
          unless $status;

        my ($type, $package, $name, $details) = $csv->fields;

        die "Cannot parse line $line"
          unless all { length } ($type, $package, $name);

        push(@names, $name);
    }

    return @names;
}

=back

=cut

1;

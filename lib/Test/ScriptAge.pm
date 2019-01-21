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

package Test::ScriptAge;

=head1 NAME

Test::ScriptAge -- routines relating to the age of Perl scripts

=head1 SYNOPSIS

  my $executable_epoch = Test::ScriptAge::our_modification_epoch();
  print 'This script was last modified at ' . localtime($executable_epoch) . "\n";

  my $perl_epoch = Test::ScriptAge::perl_modification_epoch();
  print 'Perl was last modified at ' . localtime($perl_epoch) . "\n";

=head1 DESCRIPTION

Routines to calculated modification times of Perl scripts.

=cut

use strict;
use warnings;
use autodie;

use Exporter qw(import);

BEGIN {
    our @EXPORT_OK = qw(
      perl_modification_epoch
      our_modification_epoch
    );
}

use File::stat;
use File::Spec::Functions qw(rel2abs);
use List::Util qw(max);

=head1 FUNCTIONS

=over 4

=item find_tests_by_name(NAME)

Find the test case named NAME.

=cut

sub perl_modification_epoch {
    my $perlpath = rel2abs($^X);
    return stat($perlpath)->mtime;
}

sub our_modification_epoch {
    my (undef, $callerpath, undef) = caller;

    my @paths = map { rel2abs($_) } ($callerpath, values %INC);
    if (my @relative = grep { !/^\// } @paths){
        warn 'Relative paths in running_epoch: '.join(', ', @relative);
    }
    my @epochs = map { stat($_)->mtime } @paths;
    return max @epochs;
}

=back

=cut

1;


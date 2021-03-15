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
  print encode_utf8('This script was last modified at ' . localtime($executable_epoch) . "\n");

  my $perl_epoch = Test::ScriptAge::perl_modification_epoch();
  print encode_utf8('Perl was last modified at ' . localtime($perl_epoch) . "\n");

=head1 DESCRIPTION

Routines to calculated modification times of Perl scripts.

=cut

use v5.20;
use warnings;
use utf8;

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
use Unicode::UTF8 qw(encode_utf8);

=head1 FUNCTIONS

=over 4

=item perl_modification_epoch

Calculate the time our Perl was last modified.

=cut

sub perl_modification_epoch {
    my $perlpath = rel2abs($^X);
    return stat($perlpath)->mtime;
}

=item our_modification_epoch

Calculate the time our scripts, including all libraries, was last modified.

=cut

sub our_modification_epoch {
    my (undef, $callerpath, undef) = caller;

    my @paths = map { rel2abs($_) } ($callerpath, values %INC);
    if (my @relative = grep { !/^\// } @paths){
        warn encode_utf8(
            'Relative paths in running_epoch: '.join(', ', @relative));
    }
    my @epochs = map { stat($_)->mtime } @paths;
    return max @epochs;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

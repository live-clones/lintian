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

use v5.20;
use warnings;
use utf8;

use Exporter qw(import);

BEGIN {
    our @EXPORT_OK = qw(
      read_config
      write_config
    );
}

use Carp;
use Const::Fast;
use List::SomeUtils qw(any);
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Deb822::File;

const my $SPACE => q{ };
const my $COLON => q{:};
const my $NEWLINE => qq{\n};

=head1 FUNCTIONS

=over 4

=item read_config(PATH, HASHREF)

Reads the configuration file located at PATH into a hash and
returns it. When also passed a HASHREF, will fill that instead.

=cut

sub read_config {
    my ($configpath) = @_;

    croak encode_utf8("Cannot find file $configpath.")
      unless -e $configpath;

    my $deb822 = Lintian::Deb822::File->new;
    my @sections = $deb822->read_file($configpath);
    die encode_utf8("$configpath does not have exactly one paragraph")
      unless @sections == 1;

    my $config = $sections[0];

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
    for my $name (sort $testcase->names) {

        my @elements = $testcase->trimmed_list($name);

        # multi-line output for some fields
        if (@elements > 1
            && any { fc($_) eq fc($name) } qw(Test-For Test-Against)) {
            push(@lines, $name . $COLON . $NEWLINE);
            push(@lines, $SPACE . $_ . $NEWLINE) for @elements;
            next;
        }

        push(@lines,
            $name . $COLON . $SPACE . $testcase->value($name) . $NEWLINE);
    }

    $desc->append_utf8(@lines);

    return;
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

#!/usr/bin/perl

# Copyright © 2014 Jakub Wilk <jwilk@jwilk.net>

# This program is free software.  It is distributed under the terms of
# the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, you can find it on the World Wide
# Web at <https://www.gnu.org/copyleft/gpl.html>, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

use strict;
use warnings;

use English qw(-no_match_vars);
use Getopt::Long ();

use Lintian::Profile ();
use Lintian::Data ();
use Lintian::Check qw(check_spelling check_spelling_picky);

our $VERSION = '0.0';

sub show_version
{
    print "spellintian $VERSION\n";
    exit 0;
}

sub show_help
{
    print <<'EOF' ;
Usage: spellintian [--picky] [FILE...]
EOF
    exit 0;
}

my $profile = Lintian::Profile->new;
Lintian::Data->set_vendor($profile);

my $picky = 0;
{
    local $SIG{__WARN__} = sub {
        my ($message) = @_;
        $message =~ s/\A([[:upper:]])/lc($1)/e;
        $message =~ s/\n+\z//;
        print {*STDERR} "spellintian: $message\n";
        exit(1);
    };
    Getopt::Long::Configure('gnu_getopt');
    Getopt::Long::GetOptions(
        '--picky' => \$picky,
        'h|help' => \&show_help,
        'version' => \&show_version,
    ) or exit(1);
}

sub spellcheck
{
    my ($path, $text) = @_;
    my $prefix = $path ? "$path: " : q{};
    my $spelling_error_handler = sub {
        my ($mistake, $correction) = @_;
        print "$prefix$mistake -> $correction\n";
    };
    check_spelling($text, $spelling_error_handler);
    if ($picky) {
        check_spelling_picky($text, $spelling_error_handler);
    }
    return;
}

if (not @ARGV) {
    my $text;
    {
        local $RS = undef;
        $text = <STDIN>;
    }
    spellcheck(undef, $text);
} else {
    for my $path (@ARGV) {
        my $text;
        open(my $fh, '<', $path) or die $ERRNO;
        {
            local $RS = undef;
            $text = <$fh>;
        }
        close($fh) or die $ERRNO;
        spellcheck($path, $text);
    }
}

END {
    close(STDOUT) or die $ERRNO;
    close(STDERR) or die $ERRNO;
}

# vim:ts=4 sts=4 sw=4 et

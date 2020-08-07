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

package spellintian;

use v5.20;
use warnings;
use utf8;
use autodie;

use Getopt::Long();
use Path::Tiny;

use Lintian::Data;
use Lintian::Spelling qw(check_spelling check_spelling_picky);
use Lintian::Profile;

my @RESTRICTED_CONFIG_DIRS= split(/:/, $ENV{'LINTIAN_RESTRICTED_CONFIG_DIRS'});
my @CONFIG_DIRS = split(/:/, $ENV{'LINTIAN_CONFIG_DIRS'});

sub load_profile {
    my ($profile_name, $options) = @_;
    my %opt = (
        'restricted-search-dirs' => \@RESTRICTED_CONFIG_DIRS,
        %{$options // {}},
    );
    require Lintian::Profile;

    my $profile = Lintian::Profile->new;
    $profile->load($profile_name, \@CONFIG_DIRS, \%opt);

    return $profile;
}

sub show_version {
    my $version = $ENV{LINTIAN_VERSION};
    print "spellintian v${version}\n";
    exit 0;
}

sub show_help {
    print <<'EOF' ;
Usage: spellintian [--picky] [FILE...]
EOF
    exit 0;
}

sub spellcheck {
    my ($path, $picky, $text) = @_;
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

sub main {
    my $profile = load_profile();
    my $picky = 0;
    my $exit_code = 0;
    Lintian::Data->set_vendor($profile);
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
            'picky'   => \$picky,
            'h|help'  => \&show_help,
            'version' => \&show_version,
        ) or exit(1);
    }

    if (not @ARGV) {
        my $text = do { local $/; <STDIN> };
        spellcheck(undef, $picky, $text);
    } else {
        my $ok = 0;
        for my $path (@ARGV) {
            my $text;
            if (not -f $path) {
                print STDERR "$path is not a file\n";
                next;
            }
            $ok = 1;
            $text = path($path)->slurp;
            spellcheck($path, $picky, $text);
        }
        $exit_code = 1 if not $ok;
    }
    exit($exit_code);
}

END {
    close(STDOUT);
    close(STDERR);
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

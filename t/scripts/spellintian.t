#!/usr/bin/perl

# Copyright (C) 2014-2016 Jakub Wilk <jwilk@jwilk.net>
# Copyright (C) 2017-2022 Axel Beckert <abe@debian.org>
#
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

use strict;
use warnings;

use Const::Fast;
use IPC::Run3;
use List::SomeUtils qw(uniq);
use Array::Utils qw(intersect);
use Test::More tests => 8;

const my $NEWLINE => qq{\n};
const my $DOT => q{.};
const my $WAIT_STATUS_SHIFT => 8;

$ENV{'LINTIAN_BASE'} //= $DOT;

my $cmd_path = "$ENV{LINTIAN_BASE}/bin/spellintian";
my $spelling_data = "$ENV{LINTIAN_BASE}/data/spelling/corrections";
my @word_lists
  = qw(/usr/share/dict/american-english /usr/share/dict/british-english);

# See #1019541 why some valid words are ignored and still ok to be
# listed as a misspelled word.
my @valid_but_very_seldom_words = qw(bellow singed want's);

# See #865055 why "iff" is wrong. "publically" is a seldom, but valid
# English word, is used in the OpenSSL license and hence causes quite
# some false positives, when being added (again).
my @valid_words = qw(iff publically);

sub t {
    my ($input, $expected, @options) = @_;

    my @command = ($cmd_path, @options);
    my $output;
    run3(\@command, \$input, \$output);

    my $status = ($? >> $WAIT_STATUS_SHIFT);
    is($status, 0, 'exit status 0');
    is($output, $expected, 'expected output');

    return;
}

my $s = "A familar brown gnu allows\nto jump over the lazy dog.\n";

t($s,
    'familar -> familiar'
      . $NEWLINE
      . '"allows to" -> "allows one to"'
      . $NEWLINE);
t(
    $s,
    'familar -> familiar'
      . $NEWLINE
      . '"allows to" -> "allows one to"'
      . $NEWLINE
      . 'gnu -> GNU'
      . $NEWLINE,
    '--picky'
);

foreach my $word_list (@word_lists) {
    open(my $wl_fh, '<', $word_list)
      or die "Can't open $word_list for reading: $!";
    local $/ = undef; # enable localized slurp mode
    push(@valid_words, split(/\n/, <$wl_fh>));
    close $wl_fh;
}

# Don't list identical words from American and British English twice.
@valid_words = uniq(@valid_words);

# Ignore words which are valid but very seldom and unlikely to show up
# in Debian packages.
foreach my $valid_but_very_seldom_word (@valid_but_very_seldom_words) {
    @valid_words = grep { !/^$valid_but_very_seldom_word$/ } @valid_words;
}

my $iff = 0;
my $publically = 0;
my @case_sen;
my @equal;
my @valid_but_listed_words = qw();
my @bad_spellings = qw();
my @good_spellings = qw();

open(my $sp_fh, '<', $spelling_data)
  or die "Can't open $spelling_data for reading: $!";
while (my $corr = <$sp_fh>) {
    next if $corr =~ m{ ^\# | ^$ }x;
    chomp($corr);

    my ($wrong, $good) = split(/\|\|/, $corr);
    # Check for corrections equal to original
    if ($wrong eq $good) {
        push @equal, $wrong;
        # Check if case sensitive corrections have been added to the wrong
        # file (data/spelling/corrections, not data/spelling/corrections-case).
        # Bad example from #883041: german||German
    } elsif ($wrong eq lc($good)) {
        push @case_sen, $wrong;
    }

    # Needed later, e.g. for checking against lists of valid words.
    push(@bad_spellings, $wrong);
    push(@good_spellings, $good);
}
close($sp_fh);

ok(
    scalar(@equal) == 0,
    "No no-op correction present in ${spelling_data} ("
      . join(', ', @equal) . ')'
);
ok(
    scalar(@case_sen) == 0,
    "No case sensitive correction present in ${spelling_data} ("
      . join(', ', @case_sen) . ')'
);

# Check if valid words have beeing has been added as correction.
my %word_count = ();
foreach my $word (@valid_words, @bad_spellings) {
    $word_count{$word}++;
}
foreach my $word (keys %word_count) {
    push(@valid_but_listed_words, $word) if $word_count{$word} > 1;
}

ok(
    scalar(@valid_but_listed_words) == 0,
    "No valid word is present in ${spelling_data} ("
      . join(', ', sort @valid_but_listed_words) . ')'
);

my @good_bad_ugly = intersect(@bad_spellings, @good_spellings);

ok(
    scalar(@good_bad_ugly) == 0,
    'No bad spelling is listed as good spelling for another bad spelling ('
      . join(', ', @good_bad_ugly) . ')'
);

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

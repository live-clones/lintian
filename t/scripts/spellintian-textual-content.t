#!/usr/bin/perl

# Copyright (C) 2014-2016 Jakub Wilk <jwilk@jwilk.net>
# Copyright (C) 2017-2023 Axel Beckert <abe@debian.org>
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

# TODO: lintian should probably find these issues itself when running
# against itself , i.e. without having a specific check in the test
# suite for this. That way we especially also could use Lintian
# overrides to declare false positives.

use strict;
use warnings;

use Const::Fast;
use IPC::Run3;
use List::SomeUtils qw(uniq);
use Test::More tests => 4;

const my $NEWLINE => qq{\n};
const my $DOT => q{.};
const my $EMPTY => q{};
const my $WAIT_STATUS_SHIFT => 8;

$ENV{'LINTIAN_BASE'} //= $DOT;

my $cmd_path = "$ENV{LINTIAN_BASE}/bin/spellintian";
my @list_of_tag_files = glob('tags/*/*.tag');
my @list_of_doc_files = (
    glob('doc/tutorial/Lintian/Tutorial/*.pod doc/examples/tags/m/*.desc'),
    qw(
      doc/README.developers.pod
      doc/lintian.rst
      doc/releases.md
      doc/tutorial/Lintian/Tutorial.pod
    )
);

sub t {
    my ($filetype, @files) = @_;
    my @command = ($cmd_path, @files);
    my $output;
    run3(\@command, undef, \$output);

    my $status = ($? >> $WAIT_STATUS_SHIFT);
    is($status, 0, "Exit status is 0 when checking $filetype");
    is($output, $EMPTY, "No spelling errors in $filetype");

    return;
}

t('tags', @list_of_tag_files);
t('docs', @list_of_doc_files);

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

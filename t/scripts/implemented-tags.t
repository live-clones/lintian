#!/usr/bin/perl

# Copyright (C) 2009 by Raphael Geissert <atomo64@gmail.com>
# Copyright (C) 2009 Russ Allbery <rra@debian.org>
#
# This file is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.

use strict;

use Test::More;
use Test::Lintian;

# Exclude the following tags, which are handled specially and can't be
# detected by this script.
our $EXCLUDE =
    join('|', qw(.*-script-but-no-.*-dep$
                 .*-contains-.*-control-dir$
                 ^maintainer-script-needs-depends-on.*
                 .*-contains-.*-file$
                 .*-contains-cvs-conflict-copy$
                 .*-does-not-load-confmodule$
                 .*-name-missing$
                 .*-address-missing$
                 .*-address-malformed$
                 .*-address-looks-weird$
                 .*-address-is-on-localhost$
                 .*-address-causes-mail-loops-or-bounces$
                 ^wrong-debian-qa-address-set-as-maintainer$
                 ^wrong-debian-qa-group-name$
                 ^example.*interpreter.*
                 ^example-script-.*$
                 ^example-shell-script-.*$
                 ^hardening-.*$
                ));

# Find all of the check description files.  We'll do one check per
# description.  Exclude "lintian.desc" as it does not have a perl
# module like other checks.
our @CHECKNAMES = map {
    s,^\Q$ENV{'LINTIAN_ROOT'}\E/checks/(.+)\.desc$,$1,;
    $_
 } (grep {!m,/lintian\.desc$, } <$ENV{LINTIAN_ROOT}/checks/*.desc>);

plan tests => scalar @CHECKNAMES;

test_tags_implemented ( {'exclude-pattern' => $EXCLUDE},
                        "$ENV{LINTIAN_ROOT}/checks", @CHECKNAMES);


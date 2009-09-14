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
use Util qw(read_dpkg_control slurp_entire_file);

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
                 .*-not-full-name$
                 .*-address-looks-weird$
                 .*-address-is-on-localhost$
                 ^wrong-debian-qa-address-set-as-maintainer$
                 ^wrong-debian-qa-group-name$
                 ^malformed-override$
                 ^example.*interpreter.*
                 ^example-script-.*$
                 ^example-shell-script-.*$
                ));

# Find all of the check description files.  We'll do one check per
# description.
our @DESCS = (<$ENV{LINTIAN_ROOT}/checks/*.desc>);
plan tests => scalar(@DESCS);

# For each desc file, build a list of tags and then scan the corresponding
# source code looking for use of that tag.  The scanning is fairly
# simple-minded.
for my $desc (@DESCS) {
    my @tags = map { $_->{tag} || () } read_dpkg_control($desc);
    @tags = grep { !/$EXCLUDE/o } @tags;
    my $file;
    if ($desc =~ m,/lintian\.desc$,) {
        $file = "$ENV{LINTIAN_ROOT}/frontend/lintian";
    } else {
        $file = $desc;
        $file =~ s,\.desc$,,;
    }
    my $code = slurp_entire_file($file);
    my @missing;
    for my $tag (@tags) {
        push(@missing, $tag) unless $code =~ /\Q$tag/;
    }
    my $short = $desc;
    $short =~ s,^\Q$ENV{LINTIAN_ROOT}/*,,;
    is(join(', ', @missing), '', "$short has all tags implemented");
}

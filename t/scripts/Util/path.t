#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 12;

# Util exports fail, which clashes with Test::More, so we
# have to be explicit about the import(s).
BEGIN { use_ok('Util', qw(resolve_pkg_path)); }

# Safe - absolute
is(resolve_pkg_path('/usr/share/java', '/usr/share/ant/file'), 'usr/share/ant/file', 'Safe absolute path');
is(resolve_pkg_path('/usr/share/ant', '/'), '.', 'Safe absolute root');

# Safe - relative
is(resolve_pkg_path('/usr/share/java', './file'), 'usr/share/java/file', 'Safe simple same-dir path');
is(resolve_pkg_path('/usr/share/java', '../ant/file'), 'usr/share/ant/file', 'Safe simple relative path');
is(resolve_pkg_path('/usr/share/java', '../../../usr/share/ant/file'), 'usr/share/ant/file', 'Safe absurd relative path');
is(resolve_pkg_path('/usr/share/java', '.'), 'usr/share/java', 'Safe relative dot path');
is(resolve_pkg_path('/', '.'), '.', 'Safe relative root dot');
is(resolve_pkg_path('/', 'usr/..'), '.', 'Safe absurd relative root path');
is(resolve_pkg_path('/usr/share/java', '../../../'), '.', 'Safe absurd relative path to root');

# Unsafe
ok(!resolve_pkg_path('/usr/share/ant', '../../../../etc/passwd'), 'Unsafe - relative escape root');
ok(!resolve_pkg_path('/usr/share/ant', '/../etc/passwd'), 'Unsafe - absolute escape root');

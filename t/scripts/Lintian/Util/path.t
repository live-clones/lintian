#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 12;

# Lintian::Util exports fail, which clashes with Test::More, so we
# have to be explicit about the import(s).
BEGIN { use_ok('Lintian::Util', qw(normalize_pkg_path)); }

# Safe - absolute
is(normalize_pkg_path('/usr/share/java', '/usr/share/ant/file'), 'usr/share/ant/file', 'Safe absolute path');
is(normalize_pkg_path('/usr/share/ant', '/'), '.', 'Safe absolute root');

# Safe - relative
is(normalize_pkg_path('/usr/share/java', './file'), 'usr/share/java/file', 'Safe simple same-dir path');
is(normalize_pkg_path('/usr/share/java', '../ant/file'), 'usr/share/ant/file', 'Safe simple relative path');
is(normalize_pkg_path('/usr/share/java', '../../../usr/share/ant/file'), 'usr/share/ant/file', 'Safe absurd relative path');
is(normalize_pkg_path('/usr/share/java', '.'), 'usr/share/java', 'Safe relative dot path');
is(normalize_pkg_path('/', '.'), '.', 'Safe relative root dot');
is(normalize_pkg_path('/', 'usr/..'), '.', 'Safe absurd relative root path');
is(normalize_pkg_path('/usr/share/java', '../../../'), '.', 'Safe absurd relative path to root');

# Unsafe
ok(!normalize_pkg_path('/usr/share/ant', '../../../../etc/passwd'), 'Unsafe - relative escape root');
ok(!normalize_pkg_path('/usr/share/ant', '/../etc/passwd'), 'Unsafe - absolute escape root');

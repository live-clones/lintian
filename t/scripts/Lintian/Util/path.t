#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 18;

# Lintian::Util exports fail, which clashes with Test::More, so we
# have to be explicit about the import(s).
BEGIN { use_ok('Lintian::Util', qw(normalize_pkg_path)); }

# Safe - absolute
is(normalize_pkg_path('usr/share/java', '/usr/share/ant/file'),
    'usr/share/ant/file', 'Safe absolute path');
is(normalize_pkg_path('usr/share/ant', '/'), q{}, 'Safe absolute root');

# Safe - relative
is(normalize_pkg_path('/usr/share/java', './file/.'),
    'usr/share/java/file', 'Safe simple same-dir path');
is(normalize_pkg_path('/usr/share/java', '../ant/./file'),
    'usr/share/ant/file', 'Safe simple relative path');
is(
    normalize_pkg_path(
        'usr/share/java', '../../../usr/./share/../share/./ant/file'
    ),
    'usr/share/ant/file',
    'Safe absurd relative path'
);
is(
    normalize_pkg_path(
        'usr/share/java/../../../usr/./share/../share/./ant/file'),
    'usr/share/ant/file',
    'Safe absurd single path argument'
);
is(normalize_pkg_path('usr/share/java', '.'),
    'usr/share/java', 'Safe relative dot path');
is(normalize_pkg_path('/', '.'), q{}, 'Safe relative root dot');
is(normalize_pkg_path('/', 'usr/..'), q{}, 'Safe absurd relative root path');
is(normalize_pkg_path('usr/share/java', '../../../'),
    q{}, 'Safe absurd relative path to root');
is(normalize_pkg_path('.'), q{}, 'Safe single argument root dot');
is(normalize_pkg_path('/'), q{}, 'Safe single argument root slash');
is(normalize_pkg_path('usr/..'), q{},'Safe absurd single relative root path');
is(normalize_pkg_path('usr/share/java/../../../'),
    q{}, 'Safe absurd single relative path to root');

# Unsafe
is(normalize_pkg_path('/usr/share/ant', '../../../../etc/passwd'),
    undef, 'Unsafe - relative escape root');
is(normalize_pkg_path('/usr/share/ant', '/../etc/passwd'),
    undef, 'Unsafe - absolute escape root');
is(normalize_pkg_path('/usr/../../etc/passwd'),
    undef, 'Unsafe - single path escape root');

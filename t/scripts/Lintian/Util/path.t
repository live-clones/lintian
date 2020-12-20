#!/usr/bin/perl

use strict;
use warnings;

use Const::Fast;
use Test::More tests => 18;

const my $EMPTY => q{};
const my $SLASH => q{/};
const my $DOT => q{.};

# Lintian::Util exports fail, which clashes with Test::More, so we
# have to be explicit about the import(s).
BEGIN {
    use_ok('Lintian::Util', qw(normalize_pkg_path normalize_link_target));
}

# Safe - absolute
is(normalize_link_target('usr/share/java', '/usr/share/ant/file'),
    'usr/share/ant/file', 'Safe absolute path');
is(normalize_link_target('usr/share/ant', $SLASH),
    $EMPTY, 'Safe absolute root');

# Safe - relative
is(normalize_link_target('/usr/share/java', './file/.'),
    'usr/share/java/file', 'Safe simple same-dir path');
is(normalize_link_target('/usr/share/java', '../ant/./file'),
    'usr/share/ant/file', 'Safe simple relative path');
is(
    normalize_link_target(
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
is(normalize_link_target('usr/share/java', $DOT),
    'usr/share/java', 'Safe relative dot path');
is(normalize_link_target($SLASH, $DOT), $EMPTY, 'Safe relative root dot');
is(normalize_link_target($SLASH, 'usr/..'),
    $EMPTY, 'Safe absurd relative root path');
is(normalize_link_target('usr/share/java', '../../../'),
    $EMPTY, 'Safe absurd relative path to root');
is(normalize_pkg_path($DOT), $EMPTY, 'Safe single argument root dot');
is(normalize_pkg_path($SLASH), $EMPTY, 'Safe single argument root slash');
is(normalize_pkg_path('usr/..'),
    $EMPTY, 'Safe absurd single relative root path');
is(normalize_pkg_path('usr/share/java/../../../'),
    $EMPTY, 'Safe absurd single relative path to root');

# Unsafe
is(normalize_link_target('/usr/share/ant', '../../../../etc/passwd'),
    undef, 'Unsafe - relative escape root');
is(normalize_link_target('/usr/share/ant', '/../etc/passwd'),
    undef, 'Unsafe - absolute escape root');
is(normalize_pkg_path('/usr/../../etc/passwd'),
    undef, 'Unsafe - single path escape root');

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

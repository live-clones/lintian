#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 6;

BEGIN { use_ok('Lintian::Util', qw(run_cmd)); }

eval {run_cmd('/bin/true');};
is($@, '', 'Basic run (/bin/true)');

eval {run_cmd('true');};
is($@, '', 'Basic run (true using PATH)');

eval {run_cmd({ 'chdir' => '/bin' }, './true');};
is($@, '', 'Basic run (cd /bin && ./true)');

eval {
    run_cmd({ 'update-env-vars' => { 'FOO' => 'bar', } },
        $^X, '-e', '$ENV{"FOO"} eq "bar" or die("ENV passing failed");');
};
is($@, '', "Basic run with env ($^X)");

eval {run_cmd({ 'out' => '/dev/null' }, 'true');};
is($@, '', 'Basic run STDOUT redirect (true)');

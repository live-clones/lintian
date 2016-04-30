#!/usr/bin/perl -w

use strict;
use warnings;
use Test::More tests => 2;

use Lintian::DepMap;

my $obj = Lintian::DepMap->new;

$obj->initialise;

$obj->add('A');
$obj->add('B', 'A');
$obj->satisfy('A');
$obj->initialise;
is(join(', ', $obj->selectable),
    'A','Only A is selectable after reinitialising');

$obj->satisfy('A');
is(join(', ', $obj->selectable),
    'B','B is selectable after A has been satisfied');

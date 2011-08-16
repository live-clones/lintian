#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 7;

BEGIN { use_ok('Lintian::Internal::PackageList'); }

my $plist = Lintian::Internal::PackageList->new('changes');
my $input = {
        'source' => 'src',
        'version' => '0.10',
        'file' => 'src_0.10.changes',
        'timestamp' => '1264616563', # Release date of S-V 3.8.4 (according to our data files)
        'random-field' => 'hallo world',
};
my $output;
my @contents;
my $orig_file = $input->{'file'}; # safe for later

$plist->set($input->{'source'}, $input);
@contents = $plist->get_all;

ok(scalar @contents == 1, "Contents one element");
is($contents[0], $input->{'source'}, "Element has the right name");

# Change input, output should be unaffected
$input->{'file'} = "lalalala";

$output = $plist->get($input->{'source'});

ok($output, "get returns a defined object");
is($output->{'source'}, $input->{'source'}, "Input{source} eq Output{source}");

isnt($output->{'random-field'}, "Output contains random-field");
is($output->{'file'}, $orig_file, "Output{file} is unaffected by modification");


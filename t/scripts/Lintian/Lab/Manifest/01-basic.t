#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 7;

BEGIN { use_ok('Lintian::Lab::Manifest'); }

my $plist = Lintian::Lab::Manifest->new('changes');
my $input = {
    'source' => 'src',
    'version' => '0.10',
    'file' => 'src_0.10.changes',
    'architecture' => 'i386',
    # Release date of S-V 3.8.4 (according to our data files)
    'timestamp' => '1264616563',
    'random-field' => 'hallo world',
};
my $output;
my @contents;
my @keys;
my $orig_file = $input->{'file'}; # save for later

$plist->set($input);
# Collect all entries and their keys
$plist->visit_all(sub { my ($v, @k) = @_; push @contents, $v; push @keys, \@k}
);

is(@contents, 1, 'Contents one element');
is($contents[0]{'source'}, $input->{'source'}, 'Element has the right name');

# Change input, output should be unaffected
$input->{'file'} = 'lalalala';

$output = $plist->get(@{ $keys[0] });

ok($output, 'get returns a defined object');
is($output->{'source'}, $input->{'source'}, 'Input{source} eq Output{source}');

isnt($output->{'random-field'}, 'Output contains random-field');
is($output->{'file'}, $orig_file,'Output{file} is unaffected by modification');


#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
eval 'use Test::Pod::Coverage';
plan skip_all => 'Test::Pod::Coverage is required for testing POD coverage'
    if $@;

my @modules = qw(
		Lintian::Check
		Lintian::Collect
		Lintian::Command
		Lintian::Data
		Lintian::Tag::Info
	);
# TODO:
#		Lintian::Collect::Binary
#		Lintian::Collect::Source
#		Lintian::Output
#		Lintian::Output::ColonSeparated
#		Lintian::Output::LetterQualifier
#		Lintian::Output::XML
#		Lintian::Relation
#		Lintian::Schedule

plan tests => scalar(@modules);

# Ensure the following modules are documented:
for my $module (@modules) {
    pod_coverage_ok($module, "$module is covered");
}

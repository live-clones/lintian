#!/usr/bin/perl

# Test for complete coverage of tags in profiles
#  - side-effect, test that all tags and checks
#    in the profiles are valid.

use strict;
use warnings;

use File::Find::Rule;
use Test::More;

use Lintian::Deb822Parser qw(read_dpkg_control);

use constant EMPTY => q{};

my $known_tests = 0;

my $root = $ENV{'LINTIAN_TEST_ROOT'} // q{.};

my %CHECKS;
my %TAGS;

# find all tags
my @tagpaths = File::Find::Rule->file->name('*.desc')->in("$root/tags");
for my $desc (@tagpaths) {
    my @sections = read_dpkg_control($desc);
    BAIL_OUT("$desc does not have exactly one paragraph")
      if (scalar(@sections) != 1);
    my $header = $sections[0];

    ok(length $header->{'tag'}, "Field Tag exists in $desc");
    ok(length $header->{'check'}. "Field Check exists in $desc");

    my $tagname = $header->{'tag'};
    my $checkname = $header->{'check'};

    $CHECKS{$checkname} = []
      unless exists $CHECKS{$checkname};
    push(@{$CHECKS{$checkname}}, $tagname);

    $TAGS{$tagname} = 0;
}

$known_tests += 2 * scalar @tagpaths;

# checks exist
my @NOLINTIAN = grep { $_ ne 'lintian' } keys %CHECKS;
ok(-f "checks/$_.desc", "check $_ exists") for sort @NOLINTIAN;

$known_tests += scalar @NOLINTIAN;

my @profilepaths
  = File::Find::Rule->file->name('*.profile')->in("$root/profiles");
for my $profile (@profilepaths) {
    my ($header, @sections) = read_dpkg_control($profile);
    my $en_checks = $header->{'enable-tags-from-check'}//EMPTY;
    my $dis_checks = $header->{'disable-tags-from-check'}//EMPTY;
    my $en_tag = $header->{'enable-tags'}//EMPTY;
    my $dis_tag = $header->{'disable-tags'}//EMPTY;

    my @checks = trim_split($en_checks);
    foreach my $check (@checks) {
        ok(exists $CHECKS{$check}, "Check $check exists in profile $profile");

        # count tags
        $TAGS{$_}++ for @{$CHECKS{$check}};
    }

    my @tags = trim_split($en_tag);
    foreach my $tag (@tags) {
        ok(exists $TAGS{$tag}, "Tag $tag exists in profile $profile");

        # count tags
        $TAGS{$tag}++;
    }

    my @disabled_checks = trim_split($dis_checks);
    ok(exists $CHECKS{$_}, "Disabled check $_ exists in profile $profile")
      for @disabled_checks;

    my @disabled_tags = trim_split($dis_tag);
    ok(exists $TAGS{$_}, "Tag $_ exists in profile $profile")
      for @disabled_tags;

    $known_tests += @checks + @tags + @disabled_checks + @disabled_tags;

    foreach my $section (@sections) {
        my @sectiontags = trim_split($section->{'tags'}//EMPTY);
        ok(exists $TAGS{$_},
            "Tag $_ in section $section exists in profile $profile")
          for @sectiontags;

        $known_tests += @sectiontags;
    }
}

cmp_ok($TAGS{$_}, '>', 0, "Tag $_ is covered by a profile")for sort keys %TAGS;

$known_tests += keys %TAGS;

done_testing($known_tests);

exit 0;

## SUBS ##

sub trim_split {
    my ($input) = @_;
    $input =~ s/^(?:\s|\n)++//o;
    $input =~ s/(?:\s|\n)++$//o;
    return split m/\s*,\s*/,  $input;
}

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

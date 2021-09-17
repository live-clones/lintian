#!/usr/bin/perl

# Test for complete coverage of tags in profiles
#  - side-effect, test that all tags and checks
#    in the profiles are valid.

use strict;
use warnings;

use Const::Fast;
use File::Find::Rule;
use Path::Tiny;
use Test::More;

use Lintian::Deb822::File;

const my $EMPTY => q{};
const my $TESTS_PER_TAG => 3;

# allow commas until all third-party profiles present in Lintian
# installations, such as dpkg/main.profile, have been converted
const my $FIELD_SEPARATOR => qr/ \s+ | \s* , \s* /sx;

my $known_tests = 0;

my $root = $ENV{'LINTIAN_BASE'} // q{.};

my %CHECKS;
my $checkdir = "$root/lib/Lintian/Check";

# find all checks
my @modulepaths = File::Find::Rule->file->name('*.pm')->in($checkdir);
for my $modulepath (@modulepaths) {
    my $relative = path($modulepath)->relative($checkdir)->stringify;
    my ($name) = ($relative =~ /^(.*)\.pm$/);

    $name =~ s{([[:upper:]])}{-\L$1}g;
    $name =~ s{^-}{};
    $name =~ s{/-}{/}g;

    $CHECKS{$name} = [];
}

my %TAGS;

# find all tags
my @tag_paths = File::Find::Rule->file->name('*.tag')->in("$root/tags");
for my $tag_path (@tag_paths) {

    my $deb822 = Lintian::Deb822::File->new;
    my @sections = $deb822->read_file($tag_path);

    BAIL_OUT("$tag_path does not have at least one paragraph")
      unless @sections;
    my $header = shift @sections;

    ok($header->declares('Tag'), "Field Tag exists in $tag_path");
    ok($header->declares('Check'), "Field Check exists in $tag_path");

    my $tag_name = $header->value('Tag');
    my $check_name = $header->value('Check');

    ok(exists $CHECKS{$check_name},
        "Check $check_name mentioned in $tag_path exists");
    $CHECKS{$check_name} //= [];
    push(@{$CHECKS{$check_name}}, $tag_name);

    $TAGS{$tag_name} = 0;
}

$known_tests += $TESTS_PER_TAG * scalar @tag_paths;

my @profilepaths
  = File::Find::Rule->file->name('*.profile')->in("$root/profiles");
for my $profile (@profilepaths) {

    my $deb822 = Lintian::Deb822::File->new;
    my ($header, @sections) = $deb822->read_file($profile);

    my @checks
      = $header->trimmed_list('Enable-Tags-From-Check', $FIELD_SEPARATOR);
    for my $check (@checks) {
        ok(exists $CHECKS{$check}, "Check $check exists in profile $profile");

        # count tags
        $TAGS{$_}++ for @{$CHECKS{$check}};
    }

    my @tags = $header->trimmed_list('Enable-Tags', $FIELD_SEPARATOR);
    for my $tag (@tags) {
        ok(exists $TAGS{$tag}, "Tag $tag exists in profile $profile");

        # count tags
        $TAGS{$tag}++;
    }

    my @disabled_checks
      = $header->trimmed_list('Disable-Tags-From-Check', $FIELD_SEPARATOR);
    ok(exists $CHECKS{$_}, "Disabled check $_ exists in profile $profile")
      for @disabled_checks;

    my @disabled_tags= $header->trimmed_list('Disable-Tags', $FIELD_SEPARATOR);
    ok(exists $TAGS{$_}, "Tag $_ exists in profile $profile")
      for @disabled_tags;

    $known_tests += @checks + @tags + @disabled_checks + @disabled_tags;

    for my $section (@sections) {
        my @sectiontags = $section->trimmed_list('Tags', $FIELD_SEPARATOR);
        ok(exists $TAGS{$_},
            "Tag $_ in section $section exists in profile $profile")
          for @sectiontags;

        $known_tests += @sectiontags;
    }
}

cmp_ok($TAGS{$_}, '>', 0,
    "Tag $_ is covered by a profile. Maybe run private/generate-profiles ?")
  for sort keys %TAGS;

$known_tests += keys %TAGS;

done_testing($known_tests);

exit 0;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

#!/usr/bin/perl

# Test for complete coverage of tags in profiles
#  - side-effect, test that all tags and checks
#    in the profiles are valid.

use strict;
use warnings;

use File::Find;
use Test::More;

use Lintian::Deb822Parser qw(read_dpkg_control);

my $root = $ENV{'LINTIAN_TEST_ROOT'} // '.';
my %CHECKS;
my %TAGS;

File::Find::find(\&check_wanted, "$root/checks");
File::Find::find(\&check_wanted, "$root/doc/examples/checks");

plan tests => scalar(keys %TAGS);

File::Find::find(\&prof_wanted, "$root/profiles");
File::Find::find(\&prof_wanted, "$root/doc/examples/profiles");

foreach my $tag (sort keys %TAGS) {
    cmp_ok($TAGS{$tag}, '>', 0, $tag);
}

exit 0;

## SUBS ##

sub parse_check {
    my ($desc) = @_;
    my @sections = read_dpkg_control($desc);
    die "$desc does not have exactly one paragraph"
      if (scalar(@sections) != 1);
    my $header = $sections[0];

    my $list = [];
    unless ($header->{'check-script'}) {
        fail("missing Check-Script field in $desc");
    }
    $CHECKS{$header->{'check-script'}} = $list;
    for my $tagname (split(q{ }, $header->{'tags'})) {
        push @$list, $tagname;
        $TAGS{$tagname} = 0;
    }
    return;
}

sub trim_split {
    my ($input) = @_;
    $input =~ s/^(?:\s|\n)++//o;
    $input =~ s/(?:\s|\n)++$//o;
    return split m/\s*,\s*/,  $input;
}

sub parse_profile {
    my ($profile) = @_;
    my ($header, @section) = read_dpkg_control($profile);
    my $en_checks = $header->{'enable-tags-from-check'}//'';
    my $dis_checks = $header->{'disable-tags-from-check'}//'';
    my $en_tag = $header->{'enable-tags'}//'';
    my $dis_tag = $header->{'disable-tags'}//'';
    foreach my $check (trim_split($en_checks)) {
        die "Unknown check ($check) in $profile.\n" unless $CHECKS{$check};
        foreach my $tag (@{$CHECKS{$check}}) {
            $TAGS{$tag}++;
        }
    }
    foreach my $tag (trim_split($en_tag)) {
        die "Unknown tag ($tag) in $profile.\n" unless exists $TAGS{$tag};
        $TAGS{$tag}++;
    }

    # Check for unknown checks in the other fields
    foreach my $check (trim_split($dis_checks)) {
        die "Unknown check in $profile.\n" unless $CHECKS{$check};
    }
    foreach my $tag (trim_split($dis_tag)) {
        die "Unknown tag ($tag) in $profile.\n" unless exists $TAGS{$tag};
    }
    # ... and other fields
    foreach my $sect (@section) {
        foreach my $tag (trim_split($sect->{'tags'}//'')) {
            die "Unknown tag ($tag) in $profile.\n" unless exists $TAGS{$tag};
        }
    }
    return;
}

sub check_wanted {
    parse_check($_) if -f && m/\.desc$/o;
    return;
}

sub prof_wanted {
    parse_profile($_) if -f && m/\.profile$/o;
    return;
}


#!/usr/bin/perl

# Test for complete coverage of tags in profiles
#  - side-effect, test that all tags and checks
#    in the profiles are valid.

use strict;
use warnings;

use Test::More;

use File::Find;
use Lintian::Util qw(read_dpkg_control); # Test::More (also) exports fail

my $root = $ENV{'LINTIAN_ROOT'};
my @profiles;
my %CHECKS;
my %TAGS;

File::Find::find(\&check_wanted, "$root/checks");

plan tests => scalar (keys %TAGS);

File::Find::find(\&prof_wanted, "$root/profiles");

foreach my $tag (sort keys %TAGS){
    cmp_ok($TAGS{$tag}, '>', 0, $tag);
}

exit 0;

## SUBS ##

sub parse_check {
    my ($desc) = @_;
    my ($header, @tags) = read_dpkg_control ($desc);
    my $list = [];
    unless ($header->{'check-script'}) {
        fail("missing Check-Script field in $desc");
    }
    $CHECKS{$header->{'check-script'}} = $list;
    for my $tag (@tags) {
        unless ($tag->{tag}) {
            fail("missing Tag field in $desc");
        }
        push @$list, $tag->{tag};
        $TAGS{$tag->{tag}} = 0;
    }
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
    foreach my $check (trim_split ($en_checks)){
        die "Unknown check ($check) in $profile.\n" unless $CHECKS{$check};
        foreach my $tag (@{$CHECKS{$check}}){
            $TAGS{$tag}++;
        }
    }
    foreach my $tag (trim_split ($en_tag)){
        die "Unknown tag ($tag) in $profile.\n" unless exists $TAGS{$tag};
        $TAGS{$tag}++;
    }

    # Check for unknown checks in the other fields
    foreach my $check (trim_split ($dis_checks)){
        die "Unknown check in $profile.\n" unless $CHECKS{$check};
    }
    foreach my $tag (trim_split ($dis_tag)){
        die "Unknown tag ($tag) in $profile.\n" unless exists $TAGS{$tag};
    }
    # ... and other fields
    foreach my $sect (@section){
        foreach my $tag (trim_split ($sect->{'tags'}//'')){
            die "Unknown tag ($tag) in $profile.\n" unless exists $TAGS{$tag};
        }
    }
}

sub check_wanted {
    parse_check ($_) if -f && m/\.desc$/o;
}

sub prof_wanted {
    parse_profile($_) if -f && m/\.profile$/o;
}


#!/usr/bin/perl

# Generates profiles for the Debian vendor
#  - Remember to add new profiles to d/rules under profiles

use strict;
use warnings;

use constant LINE_LENGTH => 80;
use constant FIELD_ORDER => ('Enable-Tags-From-Check',
                             'Disable-Tags-From-Check',
                             'Enable-Tag',
                             'Disable-Tag',
    );
use constant PARAGRAPH_ORDER => ( 'Overridable' );

use lib "$ENV{LINTIAN_ROOT}/lib";
use Lintian::Data;
use Util;

my $root = $ENV{LINTIAN_ROOT};
my @dirs = ('profiles/debian');
my @checks;
my @fatal;
my @nonfatal;

foreach my $check (<$root/checks/*.desc>){
    my ($header, undef) = read_dpkg_control($check);
    my $cname = $header->{'check-script'};
    fail "$check missing check-script\n" unless defined $cname;
    push @checks, $cname;
}

@fatal = Lintian::Data->new('output/ftp-master-fatal')->all;
@nonfatal = Lintian::Data->new('output/ftp-master-nonfatal')->all;

foreach my $dir (@dirs) {
    mkdir $dir or fail "mkdir $dir: $!" unless -d $dir;
}

generate_profile('debian/main', {
    'Enable-Tags-From-Check' => \@checks,
    });

generate_profile('debian/ftp-master-auto-reject', {
    'Enable-Tag' => [@fatal, @nonfatal],
    },
    { 'Tag' => \@fatal,
       'Overridable' => 'no',
    });

exit 0;


sub generate_profile {
    my ($profile, $main, @other) = @_;
    my $filename = "profiles/$profile.profile";
    open(my $fd, '>', $filename) or die "$filename: $!";
    print $fd "# This profile is auto-generated\n";
    print $fd "Profile: $profile\n";
    foreach my $f (FIELD_ORDER) {
        my $val = $main->{$f};
        next unless defined $val;
        format_field($fd, $f, sort @$val);
    }
    print $fd "\n";
    foreach my $para (@other) {
        format_field($fd, 'Tag', sort @{ $para->{'Tag'} });
        foreach my $f (PARAGRAPH_ORDER) {
            my $val = $para->{$f};
            next unless defined $val;
            print $fd "$f: $val\n";
        }
        print $fd "\n";
    }
    close($fd) or die "$filename: $!";
}

sub format_field {
    my ($fd, $field, @elements) = @_;
    my $llen = length($field)  + 2;
    my $first = shift @elements;
    print $fd "$field: $first";
    foreach my $el (@elements){
        my $ellen = length $el;
        if ($llen + $ellen + 2 <= LINE_LENGTH || $llen <= 2){
            print $fd ", $el";
            $llen += $ellen + 2;
        } else {
            print $fd ",\n $el";
            $llen = $ellen + 1;
        }
    }
    print $fd "\n";
}


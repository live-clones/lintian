#!/usr/bin/perl

# Generates profiles for the Debian vendor
#  - Remember to add new profiles to d/rules under profiles

use strict;
use warnings;

use constant LINE_LENGTH => 80;
use constant FIELD_ORDER => (
                             'Extends',
                             'Enable-Tags-From-Check',
                             'Disable-Tags-From-Check',
                             'Enable-Tags',
                             'Disable-Tags',
    );
use constant PARAGRAPH_ORDER => ( 'Overridable', 'Severity' );


BEGIN {
    my $root = $ENV{'LINTIAN_ROOT'}//'.';
    $ENV{'LINTIAN_ROOT'} = $root;
}

use lib "$ENV{LINTIAN_ROOT}/lib";
use Lintian::Util qw(fail read_dpkg_control strip);

my $root = $ENV{LINTIAN_ROOT};
my @dirs = ('profiles/debian');
my @checks;
my @fatal;
my @nonfatal;

foreach my $check (<$root/checks/*.desc>){
    my ($header, undef) = read_dpkg_control($check);
    my $cname = $header->{'check-script'};
    fail "$check missing check-script\n" unless defined $cname;
    # FIXME, enable apache2 when apache2.4 is uploaded to sid.
    push @checks, $cname unless $cname eq 'apache2';
}

@fatal = read_tags ('private/build-time-data/ftp-master-fatal');
@nonfatal = read_tags ('private/build-time-data/ftp-master-nonfatal');

foreach my $dir (@dirs) {
    mkdir $dir or fail "mkdir $dir: $!" unless -d $dir;
}

generate_profile('debian/main', {
    'Extends' => 'debian/ftp-master-auto-reject',
    'Enable-Tags-From-Check' => \@checks,
    'Disable-Tags' => ['hardening-no-stackprotector']
    });

generate_profile('debian/extra-hardening', {
    'Extends' => 'debian/main',
    'Enable-Tags' => ['hardening-no-stackprotector']
    });

generate_profile('debian/extra-apache2', {
    'Extends' => 'debian/main',
    'Enable-Tags-From-Check' => ['apache2'],
    });

generate_profile('debian/ftp-master-auto-reject', {
    # "lintian" is enabled by default, so we explicitly disable it.
    'Disable-Tags-From-Check' => ['lintian'],
    'Enable-Tags' => [@fatal, @nonfatal],
    },
    { 'Tags' => \@fatal,
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
        if ($f eq 'Extends') {
            format_field($fd, $f, $val);
        } else {
            format_field($fd, $f, sort @$val);
        }
    }
    print $fd "\n";
    foreach my $para (@other) {
        format_field($fd, 'Tags', sort @{ $para->{'Tags'} });
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

sub read_tags {
    my ($file) = @_;
    my @tags = ();
    open my $fd, '<', $file or die "$file: $!";
    while (<$fd>) {
        strip;
        next if /^#/ or $_ eq '';
        push @tags, $_;
    }
    close $fd;
    return @tags;
}

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

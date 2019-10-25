#!/usr/bin/perl

# Generates profiles for the Debian vendor
#  - Remember to add new profiles to d/rules under profiles

use strict;
use warnings;
use autodie;

BEGIN {
    $ENV{'LINTIAN_ROOT'} //= q{.};
}

use File::Find::Rule;
use LWP::Simple;
use Path::Tiny;

use lib "$ENV{LINTIAN_ROOT}/lib";

use Lintian::Deb822Parser qw(read_dpkg_control);
use Lintian::Util qw(strip);

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant COMMA => q{,};
use constant NEWLINE => qq{\n};

my $masterurl = 'https://ftp-master.debian.org/static/lintian.tags';
my $contents = get($masterurl);

die "Couldn't get $masterurl"
  unless defined $contents;

my ($nonfatal_string, $fatal_string)
  = ($contents =~ qr/^lintian:[^:]*nonfatal:([^:]*)fatal:([^:]*)$/);
die "Could not parse document downloaded from $masterurl"
  unless defined $nonfatal_string && defined $fatal_string;

# remove comments
$nonfatal_string =~ s/#[^\n]*\n/\n/g;
$fatal_string =~ s/#[^\n]*\n/\n/g;

# remove hyphens
$nonfatal_string =~ s/\s-\s/ /g;
$fatal_string =~ s/\s-\s/ /g;

my @nonfatal = split(' ', $nonfatal_string);
my @fatal = split(' ', $fatal_string);

print 'Found '
  . scalar @fatal
  . ' fatal and '
  . scalar @nonfatal
  . " non-fatal tags for profile ftp-master-auto-reject.\n";

my @checkdescs
  = File::Find::Rule->file->name('*.desc')->in("$ENV{LINTIAN_ROOT}/checks");

my @checks;
foreach my $desc (@checkdescs){
    my ($header, undef) = read_dpkg_control($desc);
    my $name = $header->{'check-script'};
    die "$desc missing check-script"
      unless defined $name;
    push @checks, $name;
}

my @dirs = ('profiles/debian');
foreach my $dir (@dirs) {
    path($dir)->mkpath
      unless -d $dir;
}

generate_profile(
    'debian/main',
    {
        'Extends' => ['debian/ftp-master-auto-reject'],
        'Enable-Tags-From-Check' => \@checks,
    });

generate_profile(
    'debian/ftp-master-auto-reject',
    {
        # "lintian" is enabled by default, so we explicitly disable it.
        'Disable-Tags-From-Check' => ['lintian'],
        'Enable-Tags' => [@fatal, @nonfatal],
    },
    {
        'Tags' => \@fatal,
        'Overridable' => ['no'],
    });

exit 0;

sub generate_profile {
    my ($name, @paragraphs) = @_;

    my $text =<<EOSTR;
# This profile is auto-generated
Profile: $name
EOSTR

    $text .= write_paragraph($_)foreach @paragraphs;

    path("profiles/$name.profile")->spew($text);

    return;
}

sub write_paragraph {
    my ($paragraph) = @_;

    my $text = EMPTY;

    foreach my $field (sort keys %{$paragraph}) {
        $text .= "$field:" . NEWLINE;

        my @values = sort @{$paragraph->{$field}};
        my $separator = (scalar @values > 1 ? COMMA : EMPTY);

        $text .= SPACE . $_ . $separator . NEWLINE for @values;
    }

    $text .= NEWLINE
      if length $text;

    return $text;
}

sub read_tags {
    my ($file) = @_;
    my @tags = ();
    open(my $fd, '<', $file);
    while (<$fd>) {
        strip;
        next if /^#/ or $_ eq '';
        push @tags, $_;
    }
    close($fd);
    return @tags;
}

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

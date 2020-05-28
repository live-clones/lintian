#!/usr/bin/perl

# Generates profiles for the Debian vendor
#  - Remember to add new profiles to d/rules under profiles

use v5.20;
use warnings;
use utf8;
use autodie;

BEGIN {
    $ENV{'LINTIAN_ROOT'} //= q{.};
}

use File::Find::Rule;
use List::Compare;
use List::Util qw(uniq);
use LWP::Simple;
use Path::Tiny;
use YAML::XS;

use lib "$ENV{LINTIAN_ROOT}/lib";

use Lintian::Deb822Parser qw(read_dpkg_control);

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant COMMA => q{,};
use constant HYPHEN => q{-};
use constant INDENT => q{    };
use constant NEWLINE => qq{\n};

# generate main profile
my $checkdir = "$ENV{LINTIAN_ROOT}/checks";
my @modulepaths = File::Find::Rule->file->name('*.pm')->in($checkdir);

my @allchecks;
for my $modulepath (@modulepaths) {
    my $relative = path($modulepath)->relative($checkdir)->stringify;
    my ($name) = ($relative =~ qr/^(.*)\.pm$/);

    push(@allchecks, $name);
}

# add check for tags issued by internal infrastructure
push(@allchecks, 'lintian');

generate_profile(
    'debian', 'main',
    {
        'Enable-Tags-From-Check' => \@allchecks,
    });

# generate profile for FTP Master auto-reject
my $auto_reject_url = 'https://ftp-master.debian.org/static/lintian.tags';
my $contents = get($auto_reject_url);
die "Couldn't get file from $auto_reject_url"
  unless defined $contents;

my $yaml = Load($contents);
die "Couldn't parse output from $auto_reject_url"
  unless defined $yaml;

my $base = $yaml->{lintian};
die "Couldn't parse document base for $auto_reject_url"
  unless defined $base;

my @want_fatal = uniq @{ $base->{fatal} // [] };
my @want_nonfatal = uniq @{ $base->{nonfatal} // [] };

# find all tags known to Lintian
my @known_tags;
my %new_name;
my $tagroot = "$ENV{LINTIAN_ROOT}/tags";
my @descfiles = File::Find::Rule->file()->name('*.desc')->in($tagroot);
for my $tagpath (@descfiles) {
    my @paragraphs = read_dpkg_control($tagpath);
    die "Tag in $tagpath does not have exactly one paragraph"
      unless scalar @paragraphs == 1;

    my %fields = %{ $paragraphs[0] };

    my $name = $fields{tag};
    push(@known_tags, $fields{tag});

    my @renamed_from= grep { length }
      grep { s/^\s*|\s*$//g } split(/,/, $fields{'renamed-from'} // EMPTY);

    my @taken = grep { exists $new_name{$_} } @renamed_from;

    say "Warning: Ignoring $_ as an alias for $new_name{$_} in favor of $name."
      for @taken;

    $new_name{$_} = $name for @renamed_from;
}

my $old_lc
  = List::Compare->new([@want_fatal, @want_nonfatal], [keys %new_name]);
my @old_names = $old_lc->get_intersection;
say 'FTP Master uses old tag names for auto-rejection:'
  if @old_names;
say INDENT . "- $_  =>  $new_name{$_}" for @old_names;

# replace old names
@want_fatal = uniq map { $new_name{$_} // $_ } @want_fatal;
@want_nonfatal = uniq map { $new_name{$_} // $_ } @want_nonfatal;

my $fatal_lc = List::Compare->new(\@want_fatal, \@known_tags);
my @unknown_fatal = $fatal_lc->get_Lonly;
my @fatal = $fatal_lc->get_intersection;

my $nonfatal_lc = List::Compare->new(\@want_nonfatal, \@known_tags);
my @unknown_nonfatal = $nonfatal_lc->get_Lonly;
my @nonfatal = $nonfatal_lc->get_intersection;

my @unknown = (@unknown_fatal, @unknown_nonfatal);
say 'Warning, disregarding unknown tags for profile ftp-master-auto-reject:'
  if @unknown;
say INDENT . HYPHEN . SPACE . $_ for @unknown;

say 'Found '
  . scalar @fatal
  . ' fatal and '
  . scalar @nonfatal
  . ' non-fatal tags for profile ftp-master-auto-reject.';

generate_profile(
    'debian',
    'ftp-master-auto-reject',
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
    my ($vendor, $name, @paragraphs) = @_;

    my $text =<<EOSTR;
# This profile is auto-generated
Profile: $vendor/$name
EOSTR

    $text .= write_paragraph($_) for @paragraphs;

    my $folder = "profiles/$vendor";
    path($folder)->mkpath
      unless -d $folder;

    path("$folder/$name.profile")->spew($text);

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

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

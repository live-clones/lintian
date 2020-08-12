# Copyright © 2020 Felix Lechner
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, you can find it on the World Wide
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Test::Lintian::Filter;

=head1 NAME

Test::Lintian::Filter -- Functions to select with tests to run

=head1 SYNOPSIS

  use Test::Lintian::Filter qw(find_selected_lintian_testpaths);
  my @testpaths = find_selected_lintian_testpaths('suite:changes');

=head1 DESCRIPTION

Functions that parse the optional argument 'only_run' to find the
tests that are supposed to run.

=cut

use v5.20;
use warnings;
use utf8;
use autodie;

use Exporter qw(import);

BEGIN {
    our @EXPORT_OK = qw(
      find_selected_scripts
      find_selected_lintian_testpaths
    );
}

use Carp;
use File::Spec::Functions qw(rel2abs splitpath catpath);
use File::Find::Rule;
use List::MoreUtils qw(uniq none);
use List::Util qw(any all);
use Path::Tiny;
use Text::CSV;

use Lintian::Profile;
use Test::Lintian::ConfigFile qw(read_config);

my @LINTIAN_SUITES = qw(recipes);

use constant DESC => 'desc';
use constant TWO_SEPARATED_BY_COLON => qr/([^:]+):([^:]+)/;
use constant EMPTY => q{};
use constant SPACE => q{ };

=head1 FUNCTIONS

=over 4

=item get_suitepath(TEST_SET, SUITE)

Returns a string containing all test belonging to suite SUITE relative
to path TEST_SET.

=cut

sub get_suitepath {
    my ($basepath, $suite) = @_;
    my $suitepath = rel2abs($suite, $basepath);

    croak("Cannot find suite $suite in $basepath")
      unless -d $suitepath;

    return $suitepath;
}

=item find_selected_scripts(SCRIPT_PATH, ONLY_RUN)

Find all test scripts in SCRIPT_PATH that are identified by the
user's selection string ONLY_RUN.

=cut

sub find_selected_scripts {
    my ($scriptpath, $onlyrun) = @_;

    my @found;

    my @selectors = split(m/\s*,\s*/, $onlyrun//EMPTY);

    if ((any { $_ eq 'suite:scripts' } @selectors) || !length $onlyrun) {
        @found = File::Find::Rule->file()->name('*.t')->in($scriptpath);
    } else {
        foreach my $selector (@selectors) {
            my ($prefix, $lookfor) = ($selector =~ TWO_SEPARATED_BY_COLON);

            next if defined $prefix && $prefix ne 'script';
            $lookfor = $selector unless defined $prefix;

            # look for files with the standard suffix
            my $withsuffix = rel2abs("$lookfor.t", $scriptpath);
            push(@found, $withsuffix) if (-f $withsuffix);

            # look for script with exact name
            my $exactpath = rel2abs($lookfor, $scriptpath);
            push(@found, $exactpath) if (-f $exactpath);

            # also add entire directory if name matches
            push(@found, File::Find::Rule->file()->name('*.t')->in($exactpath))
              if -d $exactpath;
        }
    }

    return sort +uniq @found;
}

=item find_selected_lintian_testpaths(TEST_SET, ONLY_RUN)

Find all those test paths with Lintian tests located in the directory
TEST_SET and identified by the user's selection string ONLY_RUN.

=cut

sub find_selected_lintian_testpaths {

    my ($testset, $onlyrun) = @_;

    my $filter = {
        'tag' => [],
        'suite' => [],
        'test' => [],
        'check' => [],
        'skeleton' => [],
    };
    my @filter_no_prefix;

    if (!length $onlyrun) {
        $filter->{suite} = [@LINTIAN_SUITES];
    } else {

        my @selectors = split(m/\s*,\s*/, $onlyrun);

        foreach my $selector (@selectors) {

            foreach my $wanted (keys %{$filter}) {
                my ($prefix, $lookfor) = ($selector =~ TWO_SEPARATED_BY_COLON);

                next if defined $prefix && $prefix ne $wanted;

                push(@{$filter->{$wanted}}, $lookfor) if length $lookfor;
                push(@filter_no_prefix, $selector) unless length $lookfor;
            }
        }
    }

    my $profile = Lintian::Profile->new;
    $profile->load(undef, [$ENV{LINTIAN_BASE}]);

    my @found;
    foreach my $suite (sort @LINTIAN_SUITES) {

        my @insuite;
        my $suitepath = get_suitepath($testset, $suite);

        # find all tests for selected suites
        if (any { $_ eq $suite } @{$filter->{suite}}) {
            push(@insuite, find_all_testpaths($suitepath));
        }

        # find explicitly selected tests
        foreach my $testname (@{$filter->{test}}) {
            my @withtests = find_testpaths_by_name($suitepath, $testname);
            push(@insuite, @withtests);
        }

        # find tests for selected checks and tags
        if (scalar @{$filter->{check}} || scalar @{$filter->{tag}}) {

            my %wanted = map { $_ => 1 } @{$filter->{check}};

            for my $tag (@{$filter->{tag}}) {

                my $taginfo = $profile->get_taginfo($tag);
                unless ($taginfo) {
                    say "Tag $tag not found";
                    return;
                }

                if (none { $tag eq $_ } $profile->enabled_tags) {
                    say "Tag $tag not enabled";
                    return;
                }

                $wanted{$taginfo->check} = 1;
            }

            for my $testpath (find_all_testpaths($suitepath)) {
                my $desc = read_config("$testpath/eval/" . DESC);

                next
                  unless $desc->exists('Check');

                for my $check ($desc->trimmed_list('Check')) {
                    push(@insuite, $testpath)
                      if exists $wanted{$check};
                }
            }
        }

        # find tests for selected skeleton
        if (scalar @{$filter->{skeleton}}) {

            my %wanted = map { $_ => 1 } @{$filter->{skeleton}};

            for my $testpath (find_all_testpaths($suitepath)) {
                my $desc = read_config("$testpath/build-spec/fill-values");

                next
                  unless $desc->exists('Skeleton');

                my $skeleton = $desc->unfolded_value('Skeleton');
                push(@insuite, $testpath)
                  if exists $wanted{$skeleton};
            }
        }

        # guess what was meant by selection without prefix
        foreach my $parameter (@filter_no_prefix) {
            push(@insuite,find_testpaths_by_name($suitepath, $parameter));

            my $checkscript = $profile->get_checkinfo($parameter);
            if ($parameter eq 'legacy' || defined $checkscript) {
                push(@insuite,
                    find_testpaths_by_name($suitepath, "$parameter-*"));
            }
        }

        push(@found, sort +uniq @insuite);
    }

    return @found;
}

=item find_all_testpaths(PATH)

Returns an array containing all test paths located under PATH. They
are identified as test paths by a specially named file containing
the test description (presently 'desc').

=cut

sub find_all_testpaths {
    my ($directory) = @_;
    my @descfiles = File::Find::Rule->file()->name(DESC)->in($directory);

    my @testpaths
      = map { my $parent = path($_)->parent->parent; $parent->stringify }
      @descfiles;

    return @testpaths;
}

=item find_testpaths_by_name(PATH, NAME)

Returns an array containing all test paths with the name NAME
located under PATH. The test paths are identified as such
by a specially named file containing the test description
(presently 'desc').

=cut

sub find_testpaths_by_name {
    my ($path, $name) = @_;

    my @named = File::Find::Rule->directory()->name($name)->in($path);
    my @testpaths= grep { defined }
      map { -f rel2abs('eval/' . DESC, $_) ? $_ : undef } @named;

    return @testpaths;
}

=item find_all_tags(TEST_PATH)

Returns an array containing all tags that somehow concern the test
located in TEST_PATH.

=cut

sub find_all_tags {
    my ($testpath) = @_;

    my $desc = read_config("$testpath/eval/" . DESC);

    return EMPTY
      unless $desc->exists('Check');

    my %tags;

    my $profile = Lintian::Profile->new;
    $profile->load(undef, [$ENV{LINTIAN_BASE}]);

    my @checks = $desc->trimmed_list('Check');
    for my $check (@checks) {
        my $checkscript = $profile->get_checkinfo($check);
        die "Unknown Lintian check $check"
          unless defined $checkscript;

        $tags{$_} = 1 for $checkscript->tags;
    }

    return keys %tags
      unless $desc->exists('Test-Against');

    # read tags from specification
    my $temp = Path::Tiny->tempfile;
    die "tagextract failed: $!"
      if system('private/tagextract', '-f', 'EWI', "$testpath/tags",
        $temp->stringify);
    my @lines = $temp->lines_utf8({ chomp => 1 });

    my $csv = Text::CSV->new({ sep_char => '|' });

    my %expected;
    foreach my $line (@lines) {

        my $status = $csv->parse($line);
        die "Cannot parse line $line: " . $csv->error_diag
          unless $status;

        my ($type, $package, $name, $details) = $csv->fields;

        die "Cannot parse line $line"
          unless all { length } ($type, $package, $name);

        $expected{$name} = 1;
    }

    # remove tags not appearing in specification
    foreach my $name (keys %tags) {
        delete $tags{$name}
          unless $expected{$name};
    }

    # add tags listed in Test-Against
    my @test_against = $desc->trimmed_list('Test-Against');
    $tags{$_} = 1 for @test_against;

    return keys %tags;
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

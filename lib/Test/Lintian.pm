# Copyright (C) 1998 Richard Braakman
# Copyright (C) 2012 Niels Thykier
# Copyright (C) 2018 Chris Lamb <lamby@debian.org>
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Test::Lintian;

=head1 NAME

Test::Lintian -- Check Lintian files for issues

=head1 SYNOPSIS

 # file 1
 use Test::Lintian;
 use Test::More import => ['done_testing'];
 test_load_profiles('some/path');

 done_testing;

 # file 2
 use Test::Lintian;
 use Test::More import => ['done_testing'];
 load_profile_for_test('vendor/profile', 'some/path', '/usr/share/lintian');
 test_check_desc('some/path/checks');
 test_load_checks('some/path/checks');
 test_tags_implemented('some/path/checks');

 done_testing;

=head1 DESCRIPTION

A testing framework for testing various Lintian files for common
errors.

=cut

use v5.20;
use warnings;
use utf8;

my $CLASS = __PACKAGE__;
my $PROFILE;
our @EXPORT = qw(
  load_profile_for_test

  test_check_desc
  test_load_checks
  test_load_profiles

  program_name_to_perl_paths
);

use parent 'Test::Builder::Module';

use Cwd qw(realpath);
use Const::Fast;
use File::Basename qw(basename);
use File::Find ();
use List::SomeUtils qw{any};
use Path::Tiny;
use Syntax::Keyword::Try;
use Unicode::UTF8 qw(valid_utf8 decode_utf8 encode_utf8);

use Lintian::Spelling qw(check_spelling);
use Lintian::Deb822;
use Lintian::Profile;
use Lintian::Tag;

const my $EMPTY => q{};
const my $COLON => q{:};
const my $MAXIMUM_TAG_LENGTH => 68;

my %visibilities = map { $_ => 1 } @Lintian::Tag::VISIBILITIES;
my %check_types = map { $_ => 1 } qw(binary changes source udeb);
my %known_html_tags = map { $_ => 1 } qw(a em i tt);

# lazy-load this (so loading a profile can affect it)
my %URLS;

=head1 FUNCTIONS

=over 4

=item test_check_desc(OPTS, CHECKS...)

Test check desc files (and the tags in them) for common errors.

OPTS is a HASHREF containing key/value pairs, which are
described below.

CHECKS is a list of paths in which to check desc files.  Any given
element in CHECKS can be either a file or a dir.  Files are assumed to
be check desc file.  Directories are searched and all I<.desc> files
in those dirs are processed.

As the number of tests depends on the number of tags in desc, it is
difficult to "plan ahead" when using this test.  It is therefore
recommended to not specify a plan and use done_testing().

This sub uses a Data file (see L</load_profile_for_test ([PROFNAME[, INC...]])>).

OPTS may contain the following key/value pairs:

=over 4

=item filter

If defined, it is a filter function that examines $_ (or its first
argument) and returns a truth value if C<$_> should be considered or
false otherwise.  C<$_> will be the path to the current file (or dir)
in question; it may be relative or absolute.

NB: I<all> elements in CHECKS are subject to the filter.

CAVEAT: If the filter rejects a directory, none of the files in it will be
considered either.  Even if the filter accepts a file, that file will
only be processed if it has the proper extension (i.e. with I<.desc>).

=item translation

If defined and a truth value, the desc files are expected to contain
translations.  Otherwise, they must be regular checks.

=back

=cut

sub test_check_desc {
    my ($opts, @dirs) = @_;

    my $builder = $CLASS->builder;
    my $colldir = '/usr/share/lintian/collection';
    my $find_opt = {'filter' => undef,};
    my $tested = 0;

    $find_opt->{'filter'} = $opts->{'filter'}
      if exists $opts->{'filter'};

    $opts //= {};

    load_profile_for_test();

    my @descs = map { _find_check($find_opt, $_) } @dirs;
    foreach my $desc_file (@descs) {

        my $bytes = path($desc_file)->slurp;
        $builder->ok(valid_utf8($bytes),
            "File $desc_file does not use a national encoding.");
        next
          unless valid_utf8($bytes);

        my $deb822 = Lintian::Deb822->new;

        my @sections;
        try {
            @sections = $deb822->read_file($desc_file);

        } catch {
            my $err = $@;
            $err =~ s/ at .*? line \d+\s*\n//;
            $builder->ok(0, "Cannot parse $desc_file");
            $builder->diag("Error: $err");
            next;
        }

        my ($header, @tagpara) = @sections;

        my $content_type = 'Check';
        my $cname = $header->value('Check-Script');
        my $ctype = $header->value('Type');
        my $i = 1; # paragraph counter.
        $builder->ok(1, "Can parse check $desc_file");

        $builder->isnt_eq($cname, $EMPTY,
            "$content_type has a name ($desc_file)");

        # From here on, we just use "$cname" as name of the check, so
        # we don't need to choose been it and $tname.
        $cname = '<missing>' if $cname eq $EMPTY;
        $tested += 2;

        if ($cname eq 'lintian') {
            my $reason = 'check "lintian" does not have a type';
            # skip these two tests for this special case...
            $builder->skip("Special case, $reason");
            $builder->skip("Special case, $reason");
        } elsif ($builder->isnt_eq($ctype, $EMPTY, "$cname has a type")) {
            my @bad;
            # new lines are not allowed, map them to "\\n" for readability.
            $ctype =~ s/\n/\\n/g;
            foreach my $type (split /\s*+,\s*+/, $ctype) {
                push @bad, $type unless exists $check_types{$type};
            }
            $builder->is_eq(join(', ', @bad),
                $EMPTY,"The type of $cname is valid");
        } else {
            $builder->skip(
                "Cannot check type of $cname is valid (field is empty/missing)"
            );
        }

        for my $tpara (@tagpara) {

            my $tag = $tpara->value('Tag');
            my $visibility = $tpara->value('Severity');
            my $explanation = $tpara->value('Explanation');

            my (@htmltags, %seen);

            $i++;

            # Tag name
            $builder->isnt_eq($tag, $EMPTY, "Tag in check $cname has a name")
              or $builder->diag("$cname: Paragraph number $i\n");
            $tag = '<N/A>' if $tag eq $EMPTY;
            $builder->ok($tag =~ /^[\w0-9.+-]+$/, 'Tag has valid characters')
              or $builder->diag("$cname: $tag\n");
            $builder->cmp_ok(length $tag, '<=', $MAXIMUM_TAG_LENGTH,
                'Tag is not too long')
              or $builder->diag("$cname: $tag\n");

            # Visibility
            $builder->ok($visibility && exists $visibilities{$visibility},
                'Tag has valid visibility')
              or $builder->diag("$cname: $tag visibility: $visibility\n");

            # Explanation
            my $mistakes = 0;
            my $handler = sub {
                my ($incorrect, $correct) = @_;
                $builder->diag(
                    "Spelling ($cname/$tag): $incorrect => $correct");
                $mistakes++;
            };
            # FIXME: There are a couple of known false-positives that
            # breaks the test.
            # check_spelling($profile, $explanation, $handler);
            $builder->is_eq($mistakes, 0,
                "$content_type $cname: $tag has no spelling errors");

            $builder->ok(
                $explanation !~ /(?:^| )(?:[Ww]e|I)\b/,
                'Tag explanation does not speak of "I", or "we"'
            )or $builder->diag("$content_type $cname: $tag\n");

            $builder->ok(
                $explanation !~ /(\S\w)\. [^ ]/
                  || $1 =~ /^\.[ge]$/, # for 'e.g.'/'i.e.'
                'Tag explanation uses two spaces after a full stop'
            ) or $builder->diag("$content_type $cname: $tag\n");

            $builder->ok($explanation !~ /(\S\w\.   )/,
                'Tag explanation uses only two spaces after a full stop')
              or $builder->diag("$content_type $cname: $tag ($1)\n");

            $builder->ok(valid_utf8($explanation),
                'Tag explanation must be written in UTF-8')
              or $builder->diag("$content_type $cname: $tag\n");

            # Check the tag explanation for unescaped <> or for unknown tags
            # (which probably indicate the same thing).
            while ($explanation
                =~ s{<([^\s>]+)(?:\s+href=\"[^\"]+\")?>.*?</\1>}{}s){
                push @htmltags, $1;
            }
            @htmltags
              = grep { !exists $known_html_tags{$_} && !$seen{$_}++ }@htmltags;
            $builder->is_eq(join(', ', @htmltags),
                $EMPTY, 'Tag explanation has no unknown html tags')
              or $builder->diag("$content_type $cname: $tag\n");

            $builder->ok($explanation !~ /[<>]/,
                'Tag explanation has no stray angle brackets')
              or $builder->diag("$content_type $cname: $tag\n");

            if ($tpara->declares('See-Also')) {

                my @issues = map { _check_reference($_) }
                  $tpara->trimmed_list('See-Also', qr{ \s* , \s* }x);

                my $text = join("\n\t", @issues);

                $builder->ok(!@issues, 'Proper references are used')
                  or $builder->diag("$content_type $cname: $tag\n\t$text");
            }
        }
    }

    $builder->cmp_ok($tested, '>', 0, 'Tested at least one desc file')
      if @descs;
    return;
}

=item test_load_profiles(ROOT, INC...)

Test that all profiles in I<ROOT/profiles> are loadable.  INC will be
the INC path used as include path for the profile.

If INC is omitted, then the include path will consist of (ROOT,
'/usr/share/lintian').  Otherwise, INC will be used as is (and should
include ROOT).

This sub will do one test per profile loaded.

=cut

sub test_load_profiles {
    my ($dir, @inc) = @_;

    my $builder = $CLASS->builder;
    my $absdir = realpath $dir;
    my $sre;
    my %opt = ('no_chdir' => 1,);

    if (not defined $absdir) {
        die encode_utf8("$dir cannot be resolved: $!");
    }

    $absdir = "$absdir/profiles";
    $sre = qr{\Q$absdir\E/};

    @inc = ($absdir, '/usr/share/lintian') unless @inc;

    $opt{'wanted'} = sub {
        my $profname = $File::Find::name;

        return
          unless $profname =~ s/\.profile$//;
        $profname =~ s/^$sre//;

        my $profile = Lintian::Profile->new;

        try {
            $profile->load($profname, \@inc, 0);

        } catch {
            $builder->diag("Load error: $@\n");
            $profile = 0;
        }

        $builder->ok($profile, "$profname is loadable.");
    };

    File::Find::find(\%opt, $absdir);
    return;
}

=item test_load_checks(OPTS, DIR[, CHECKNAMES...])

Test that the Perl module implementation of the checks can be loaded
and has a run sub.

OPTS is a HASHREF containing key/value pairs, which are
described below.

DIR is the directory where the checks can be found.

CHECKNAMES is a list of check names.  If CHECKNAMES is given, only the
checks in this list will be processed.  Otherwise, all the checks in
DIR will be processed.

For planning purposes, every check processed counts for 2 tests and
the call itself does on additional check.  So if CHECKNAMES contains
10 elements, then 21 tests will be done (2 * 10 + 1).  Filtered out
checks will I<not> be counted.

All data files created at compile time or in the file scope will be
loaded immediately (instead of lazily as done during the regular
runs).  This is done to spot missing data files or typos in their
names.  Therefore, this sub will load a profile if one hasn't been
loaded already.  (see L</load_profile_for_test ([PROFNAME[,
INC...]])>)

OPTS may contain the following key/value pairs:

=over 4

=item filter

If defined, it is a filter function that examines $_ (or its first
argument) and returns a truth value if C<$_> should be considered or
false otherwise.  C<$_> will be the path to the current file (or dir)
in question; it may be relative or absolute.

NB: filter is I<not> used if CHECKNAMES is given.

CAVEAT: If the filter rejects a directory, none of the files in it will be
considered either.  Even if the filter accepts a file, that file will
only be processed if it has the proper extension (i.e. with I<.desc>).

=back

=cut

sub test_load_checks {
    my ($opts, $dir, @check_names) = @_;

    my $builder = $CLASS->builder;

    unless (@check_names) {
        my $find_opt = {'want-check-name' => 1,};
        $find_opt->{'filter'} = $opts->{'filter'} if exists $opts->{'filter'};
        @check_names = _find_check($find_opt, $dir);
    } else {
        $builder->skip('Given an explicit list of checks');
    }

    $builder->skip('No desc files found')
      unless @check_names;

    my $profile = load_profile_for_test();

    foreach my $check_name (@check_names) {

        my $path = $profile->check_path_by_name->{$check_name};
        try {
            require $path;

        } catch {
            $builder->skip(
"Cannot check if $check_name has entry points due to load error"
            );
            next;
        }

        $builder->ok(1, "Check $check_name can be loaded");

        my $module = $profile->check_module_by_name->{$check_name};

        $builder->diag(
            "Warning: check $check_name uses old entry point ::run\n")
          if $module->can('run') && !$module->DOES('Lintian::Check');

        # setup and breakdown should only be used together with files
        my $has_entrypoint = any { $module->can($_) }
          qw(source binary udeb installable changes always files);

        if (
            !$builder->ok(
                $has_entrypoint, "Check $check_name has entry point"
            )
        ){
            $builder->diag("Expected package name is $module\n");
        }
    }
    return;
}

=item load_profile_for_test ([PROFNAME[, INC...]])

Load a Lintian::Profile and ensure Data files can be used.  This is
needed if the test needs to access a data file or if a special profile
is needed for the test.  It does I<not> test the profile for issues.

PROFNAME is the name of the profile to load.  It can be omitted, in
which case the sub ensures that a profile has been loaded.  If no
profile has been loaded, 'debian/main' will be loaded.

INC is a list of extra "include dirs" (or Lintian "roots") to be used
for finding the profile.  If not specified, it defaults to
I<$ENV{'LINTIAN_BASE'}> and I</usr/share/lintian> (in order).
INC is ignored if a profile has already been loaded.

CAVEAT: Only one profile can be loaded in a given test.  Once a
profile has been loaded, it is not possible to replace it with another
one.  So if this is invoked multiple times, PROFNAME must be omitted
or must match the name of the loaded profile.

=cut

sub load_profile_for_test {
    my ($profname, @inc) = @_;

    # We have loaded a profile and are not asked to
    # load a specific one - then current one will do.
    return $PROFILE
      if $PROFILE and not $profname;

    die encode_utf8("Cannot load two profiles.\n")
      if $PROFILE and $PROFILE->name ne $profname;

    # Already loaded? stop here
    # We just need it for spell checking, so debian/main should
    # do just fine...
    return $PROFILE
      if $PROFILE;

    $profname ||= 'debian/main';

    $PROFILE = Lintian::Profile->new;
    $PROFILE->load($profname, [@inc, $ENV{'LINTIAN_BASE'}]);

    $ENV{'LINTIAN_CONFIG_DIRS'} = join($COLON, @inc);

    return $PROFILE;
}

sub _check_reference {
    my ($see_also) = @_;

    my @issues;

    my @MARKDOWN_CAPABLE = (
        $PROFILE->menu_policy,
        $PROFILE->perl_policy,
        $PROFILE->python_policy,
        $PROFILE->java_policy,
        $PROFILE->vim_policy,
        $PROFILE->lintian_manual,
        $PROFILE->developer_reference,
        $PROFILE->policy_manual,
        $PROFILE->debconf_specification,
        $PROFILE->menu_specification,
        $PROFILE->doc_base_specification,
        $PROFILE->filesystem_hierarchy_standard,
    );

    my %by_shorthand = map { $_->shorthand => $_ } @MARKDOWN_CAPABLE;

    # We use this to check for explicit links where it is possible to use
    # a manual ref.
    unless (%URLS) {
        for my $manual (@MARKDOWN_CAPABLE) {

            my $volume = $manual->shorthand;

            for my $section_key ($manual->all){
                my $entry = $manual->value($section_key);

                my $url = $entry->{$section_key}{url};
                next
                  unless length $url;

                $URLS{$url} = "$volume $section_key";
            }
        }
    }

    if (   $see_also =~ m{^https?://bugs.debian.org/(\d++)$}
        || $see_also
        =~ m{^https?://bugs.debian.org/cgi-bin/bugreport.cgi\?/.*bug=(\d++).*$}
    ) {
        push(@issues, "replace '$see_also' with '#$1'");

    } elsif (exists $URLS{$see_also}) {
        push(@issues, "replace '$see_also' with '$URLS{$see_also}'");

    } elsif ($see_also =~ m/^([\w-]++)\s++(\S++)$/) {

        my $volume = $1;
        my $section = $2;

        if (exists $by_shorthand{$volume}) {

            my $manual = $by_shorthand{$volume};

            push(@issues, "unknown section '$section' in $volume")
              unless length $manual->markdown_citation($section);

        } else {
            push(@issues, "unknown manual '$volume'");
        }

    } else {
        # Check it is a valid reference like URLs or #123456
        # NB: "policy 10.1" references already covered above
        push(@issues, "unknown or malformed reference '$see_also'")
          if $see_also !~ /^#\d+$/ # debbugs reference
          && $see_also !~ m{^(?:ftp|https?)://} # browser URL
          && $see_also !~ m{^/} # local file reference
          && $see_also !~ m{[\w_-]+\(\d\w*\)$}; # man reference
    }

    return @issues;
}

sub _find_check {
    my ($find_opt, $input) = @_;
    $find_opt//= {};
    my $filter = $find_opt->{'filter'};

    if ($filter) {
        local $_ = $input;
        # filtered out?
        return () unless $filter->($_);
    }

    if (-d $input) {
        my (@result, $regex);
        if ($find_opt->{'want-check-name'}) {
            $regex = qr{^\Q$input\E/*};
        }
        my $wanted = sub {
            if (defined $filter) {
                local $_ = $_;
                if (not $filter->($_)) {
                    # filtered out; if a dir - filter the
                    # entire dir.
                    $File::Find::prune = 1 if -d;
                    return;
                }
            }
            return unless m/\.desc$/ and -e;
            if ($regex) {
                s/$regex//;
                s/\.desc$//;
            }
            push @result, $_;
        };
        my $opt = {
            'wanted' => $wanted,
            'no_chdir' => 1,
        };
        File::Find::find($opt, $input);
        return @result;
    }

    return ($input);
}

=item program_name_to_perl_paths(PROGNAME)

Map the program name (e.g. C<$0>) to a list of directories or/and
files that should be processed.

This helper sub is mostly useful for splitting up slow tests run over
all Perl scripts/modules in Lintian.  This allows better use of
multiple cores.  Example:


  t/scripts/my-test/
   runner.pl
   checks.t -> runner.pl
   collection.t -> runner.pl
   ...

And then in runner.pl:

  use Test::Lintian;
  
  my @paths = program_name_to_perl_paths($0);
  # test all files/dirs listed in @paths

For a more concrete example, see t/scripts/01-critic/ and the
files/symlinks beneath it.

=cut

{

    my %SPECIAL_PATHS = (
        'docs-examples' => ['doc/examples/checks'],
        'test-scripts' => [qw(t/scripts t/templates)],
    );

    sub program_name_to_perl_paths {
        my ($program) = @_;
        # We need the basename before resolving the path (because
        # afterwards it is "runner.pl" and we want it to be e.g.
        # "checks.t" or "collections.t").
        my $basename = basename($program, '.t');

        if (exists($SPECIAL_PATHS{$basename})) {
            return @{$SPECIAL_PATHS{$basename}};
        }

        return ($basename);
    }
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

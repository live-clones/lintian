#!/usr/bin/perl
use strict;
use warnings;

use Test::More;

plan skip_all => 'Not needed for coverage of Lintian'
  if $ENV{'LINTIAN_COVERAGE'};

use Test::Lintian;

BEGIN {
    # If IPCRUNDEBUG is set to 'none', reset to 0.  Unfortunately,
    # IPC::Run and IPC::Run3 reads the variables different and we end
    # up loading IPC::Run via Test::Lintian.
    $ENV{'IPCRUNDEBUG'} = 0
      if exists($ENV{'IPCRUNDEBUG'})
      && $ENV{'IPCRUNDEBUG'} eq 'none';
}

eval 'use Test::Spelling';
plan skip_all => 'Pod spell checking requires Test::Spelling' if $@;

my @GOOD_WORDS = grep {$_ ne ''} map {
    s/ \s* (?: [#] .* )? \Z//xsm;
    split(m/\s++/, $_);
} <DATA>;

add_stopwords(@GOOD_WORDS);

chdir($ENV{'LINTIAN_TEST_ROOT'}//'.')
  or die("fatal error: could not chdir to $ENV{LINTIAN_TEST_ROOT}: $!");

my @CHECKS = glob('checks/*[!.]*[!c]');
my @DIRS
  = qw(collection doc/tutorial frontend lib private reporting t/scripts t/helpers);

all_pod_files_spelling_ok(@CHECKS, @DIRS, 't/runtests');

__DATA__
# List of extra words that aspell doesn't know, but we need it to know
# about.  Comments are stripped and lines are split on white space, so
# multiple words can appear on the same line


# Names of various people that appear in the POD docs
Russ Allbery
Barratt
Braakman
Brockschmidt
Geissert
Lichtenheld
Niels Thykier
Bastien ROUCARIES

lintian Lintian Lintian's # ' # hi emacs
dpkg
libapt
debian Debian DEBIAN

# md is md5 butchered by aspell
md
# 'soft'ly which was parsed as soft'ly.
soft'ly # ' # hi emacs

# "util" is import tag ":util" from Lintian::Output, where aspell
# dropped the ":".
util

# This is wrong in general, but it happens to be a package name that
# we use as an example.
alot

# Other various names/fields/arguments/variables/expressions that
# trips aspell.  Ordered by nothing in particular
PTS QA qa uploader uploaders UPLOADER Uploaders changelog changelogs
desc COND CURVALUE subdirectory subdirectories udeb deb dsc nlist
olist KEYN BASEDIR METADATA OO TODO dir exitcode nohang substvar
substvars listref metadata blockingly checksum checksums Nativeness
src nativeness Indep debfiles diffstat gz env classpath conffiles
objdump tasksel filename Pre pre hardlink hardlinking hardlinks PROC
dirs PROFNAME CHECKNAMES COLLMAP ERRHANDLER LPKG unpacker worklist
BASEPATH stderr stdout stdin ascii html issuedtags subclasses
showdescription printables overridable processables msg ORed SIGKILLs
SIGTERM wildcard wildcards ar whitelist blacklist API amd armhf cpu
linux whitelisted blacklisted shaX sha rstrip lstrip parsers
customisation ALGO CLOC CMD DEBFILE DEST DSCFILE FOH NOCLOSE PARENTDIR
PGP STARTLINE STR UTF bitmask cp debconf rw proccessable severities
AND'ing # ' # this is getting old
superset YYYY dirname operm username whitespace
Whitespace udebs multiword recognised eqv testsuite methodx multi
multiarch relationA relationB Multi natively unordered arg CVE autodie
hashrefs namespace subdir SIGPIPE SIG blocknumber blocksub readwindow
REMOVESLASH

__END__


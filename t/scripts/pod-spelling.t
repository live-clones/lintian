#!/usr/bin/perl
use strict;
use warnings;

use Const::Fast;
use IPC::Run3;
use Test::More;

plan skip_all => 'Not needed for coverage of Lintian'
  if $ENV{'LINTIAN_COVERAGE'};

plan skip_all => 'Need newer version of aspell-en (>= 7.1)'
  if not check_aspell();

use lib "$ENV{'LINTIAN_BASE'}/lib";

use Test::Lintian;

eval 'use Test::Spelling';
plan skip_all => 'Pod spell checking requires Test::Spelling' if $@;

const my $DOT => q{.};

my @GOOD_WORDS;
while (my $line = <DATA>) {
    $line =~ s/ \s* (?: [#] .* )? \Z//xsm;
    push(@GOOD_WORDS, grep { length } split(/\s+/, $line));
}

add_stopwords(@GOOD_WORDS);

# Hardcode spelling command as Test::Spelling prefers spell over
# aspell if installed, too. This avoids a "Build-Conflicts: spell".
set_spell_cmd('aspell list -l en -p /dev/null');

chdir($ENV{'LINTIAN_BASE'} // $DOT)
  or die("fatal error: could not chdir to $ENV{LINTIAN_BASE}: $!");

my @CHECKS = glob('checks/*[!.]*[!c]');
my @DIRS= qw(bin doc/tutorial lib private reporting t/scripts t/templates);

all_pod_files_spelling_ok(@CHECKS, @DIRS);

sub check_aspell {
    # Ubuntu Precise has an old aspell-en, which does not recognise
    # "basic" stuff like "indices" or "extendable".
    my $ok = 0;

    my @command = qw{dpkg -l};
    my $output;

    run3(\@command, \undef, \$output);
    my @lines = split(/\n/, $output);

    while (defined(my $line = shift @lines)) {
        if ($line =~ m/^.i \s+ aspell-en \s+ (\S+) \s/xsm) {
            my $version = $1;
            require Lintian::Relation::Version;
            Lintian::Relation::Version->import(qw(versions_gte));
            # Print the version of aspell-en if it is not new enough
            $ok = versions_gte($version, '7.1-0~')
              ||diag("Found aspell-en $version, want 7.1-0~ or newer");
        }
    }

    return $ok;
}

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
Felix Lechner

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
linux whitelisted blacklisted shaX sha parsers EWI
customisation ALGO CLOC CMD DEBFILE DEST DSCFILE FOH NOCLOSE PARENTDIR
PGP STARTLINE STR UTF bitmask cp debconf rw processable severities
AND'ing # ' # this is getting old
superset YYYY dirname operm username whitespace
Whitespace udebs multiword recognised eqv testsuite methodx multi
multiarch relationA relationB Multi natively unordered arg CVE autodie
hashrefs namespace subdir SIGPIPE SIG blocknumber blocksub readwindow
REMOVESLASH STAMPFILE TAGNAME TCODE TESTDATA BLOCKSIZE jN
POSIX t1c2pfb init runtime txt executability writability
INHANDLE OUTHANDLES UTC timestamp faux tagname READMEs Testname
debhelper compat dh buildpackage uaccess udev AppStream plugdev dbgsym
buildinfo dfsg

Buildflags
__END__

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

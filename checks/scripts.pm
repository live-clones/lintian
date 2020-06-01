# scripts -- lintian check script -*- perl -*-
#
# This is probably the right file to add a check for the use of
# set -e in bash and sh scripts.
#
# Copyright © 1998 Richard Braakman
# Copyright © 2002 Josip Rodin
# Copyright © 2016-2019 Chris Lamb <lamby@debian.org>
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

package Lintian::scripts;

use v5.20;
use warnings;
use utf8;
use autodie;

use Capture::Tiny qw(capture);
use List::MoreUtils qw(any);
use POSIX qw(strftime);
use Try::Tiny;

use Lintian::Spelling qw($known_shells_regex);
use Lintian::Data;
use Lintian::Relation;
use Lintian::Util qw(safe_qx);

use constant EMPTY => q{};

use Moo;
use namespace::clean;

with 'Lintian::Check';

# This is a map of all known interpreters.  The key is the interpreter
# name (the binary invoked on the #! line).  The value is an anonymous
# array of two elements.  The first argument is the path on a Debian
# system where that interpreter would be installed.  The second
# argument is the dependency that provides that interpreter.
#
# $INTERPRETERS maps names of (unversioned) interpreters to the path
# they are installed and what package to depend on to use them.
#
my $INTERPRETERS = Lintian::Data->new('scripts/interpreters', qr/\s*=\>\s*/,
    \&_parse_interpreters);

# The more complex case of interpreters that may have a version number.
#
# This is a hash from the base interpreter name to a list.  The base
# interpreter name may appear by itself or followed by some combination of
# dashes, digits, and periods.
#
# The list contains the following values:
#  [<path>, <dependency-relation>, <regex>, <dependency-template>, <version-list>]
#
# Their meaning is documented in Lintian's scripts/versioned-interpreters
# file, though they are ordered differently and there are a few differences
# as described below:
#
# * <regex> has been passed through qr/^<value>$/
# * If <dependency-relation> was left out, it has been substituted by the
#   interpreter.
# * The magic values of <dependency-relation> are represented as:
#   @NO_DEFAULT_DEPS@  -> '' (i.e. an empty string)
#   @SKIP_UNVERSIONED@ ->  undef (i.e the undefined value)
# * <version-list> has been split into a list of versions.
#   (e.g. "1.6 1.8" will be ["1.6", "1.8"])
#
# A full example is:
#
#    data:
#        lua => /usr/bin, lua([\d.]+), 'lua$1', 40 50 5.1
#
#    $VERSIONED_INTERPRETERS->value ('lua') is
#       [ '/usr/bin', 'lua', qr/^lua([\d.]+)$/, 'lua$1', ["40", "50", "5.1"] ]
#
my $VERSIONED_INTERPRETERS
  = Lintian::Data->new('scripts/versioned-interpreters',
    qr/\s*=\>\s*/,\&_parse_versioned_interpreters);

# When detecting commands inside shell scripts, use this regex to match the
# beginning of the command rather than checking whether the command is at the
# beginning of a line.
my $LEADINSTR
  = '(?:(?:^|[`&;(|{])\s*|(?:if|then|do|while|!)\s+|env(?:\s+[[:alnum:]_]+=(?:\S+|\"[^"]*\"|\'[^\']*\'))*\s+)';
my $LEADIN = qr/$LEADINSTR/;

# date --date="Sat, 17 Jun 2017 20:22:36 -1000" +%s
# <https://lists.debian.org/debian-announce/2017/msg00003.html>
my $OLDSTABLE_RELEASE = 1_497_766_956;

#forbidden command in maintainer scripts
my $BAD_MAINT_CMD = Lintian::Data->new(
    'scripts/maintainer-script-bad-command',
    qr/\s*\~\~/,
    sub {
        my @sliptline = split(/\s*\~\~/, $_[1], 5);
        if(scalar(@sliptline) != 5) {
            die "Syntax error in scripts/maintainer-script-bad-command: $.";
        }
        my ($incat,$inauto,$exceptinpackage,$inscript,$regexp) = @sliptline;
        $regexp =~ s/\$[{]LEADIN[}]/$LEADINSTR/;

        $incat //= EMPTY;
        $inauto //= EMPTY;

        # trim both ends
        $incat =~ s/^\s+|\s+$//g;
        $inauto =~ s/^\s+|\s+$//g;

   # allow empty $exceptinpackage and set it synonymous to check in all package
        $exceptinpackage //= EMPTY;

        # trim both ends
        $exceptinpackage =~ s/^\s+|\s+$//g;

        if (length($exceptinpackage) == 0) {
            $exceptinpackage = '\a\Z';
        }
        # allow empty $inscript and set to synonymous to check in all script
        $inscript //= EMPTY;

        # trim both ends
        $inscript =~ s/^\s+|\s+$//g;

        if (length($inscript) == 0) {
            $inscript = '.*';
        }
        return {
            # use not not to normalize boolean
            'ignore_automatically_added' => not(not($inauto)),
            'in_cat_string' => not(not($incat)),
            'in_package' => qr/$exceptinpackage/x,
            'in_script' => qr/$inscript/x,
            'regexp' => qr/$regexp/x,
        };
    });

# Any of the following packages can satisfy an update-inetd dependency.
my $update_inetd = join(
    ' | ', qw(update-inetd inet-superserver openbsd-inetd
      inetutils-inetd rlinetd xinetd)
);

# Appearance of one of these regexes in a maintainer script means that there
# must be a dependency (or pre-dependency) on the given package.  The tag
# reported is maintainer-script-needs-depends-on-%s, so be sure to update
# scripts.desc when adding a new rule.
my @depends_needed = (
    [adduser       => '\badduser\s'],
    [gconf2        => '\bgconf-schemas\s'],
    [$update_inetd => '\bupdate-inetd\s'],
    [ucf           => '\bucf\s'],
    ['xml-core'    => '\bupdate-xmlcatalog\s'],
    ['xfonts-utils' => '\bupdate-fonts-(?:alias|dir|scale)\s'],
);

my @bashism_single_quote_regexs = (
    $LEADIN . qr'echo\s+(?:-[^e\s]+\s+)?\'[^\']*(\\[abcEfnrtv0])+.*?[\']',
    # unsafe echo with backslashes
    $LEADIN . qr'source\s+[\"\']?(?:\.\/|\/|\$|[\w~.-])\S*',
    # should be '.', not 'source'
);
my @bashism_string_regexs = (
    qr'\$\[\w+\]',               # arith not allowed
    qr'\$\{\w+\:\d+(?::\d+)?\}',   # ${foo:3[:1]}
    qr'\$\{\w+(/.+?){1,2}\}',    # ${parm/?/pat[/str]}
    qr'\$\{\#?\w+\[[0-9\*\@]+\]\}',# bash arrays, ${name[0|*|@]}
    qr'\$\{!\w+[\@*]\}',                 # ${!prefix[*|@]}
    qr'\$\{!\w+\}',              # ${!name}
    qr'(\$\(|\`)\s*\<\s*\S+\s*(\)|\`)', # $(\< foo) should be $(cat foo)
    qr'\$\{?RANDOM\}?\b',                # $RANDOM
    qr'\$\{?(OS|MACH)TYPE\}?\b',   # $(OS|MACH)TYPE
    qr'\$\{?HOST(TYPE|NAME)\}?\b', # $HOST(TYPE|NAME)
    qr'\$\{?DIRSTACK\}?\b',        # $DIRSTACK
    qr'\$\{?EUID\}?\b',            # $EUID should be "id -u"
    qr'\$\{?UID\}?\b',           # $UID should be "id -ru"
    qr'\$\{?SECONDS\}?\b',       # $SECONDS
    qr'\$\{?BASH_[A-Z]+\}?\b',     # $BASH_SOMETHING
    qr'\$\{?SHELLOPTS\}?\b',       # $SHELLOPTS
    qr'\$\{?PIPESTATUS\}?\b',      # $PIPESTATUS
    qr'\$\{?SHLVL\}?\b',                 # $SHLVL
    qr'<<<',                       # <<< here string
    $LEADIN . qr'echo\s+(?:-[^e\s]+\s+)?\"[^\"]*(\\[abcEfnrtv0])+.*?[\"]',
    # unsafe echo with backslashes
);
my @bashism_regexs = (
    qr'(?:^|\s+)function \w+(\s|\(|\Z)',  # function is useless
    qr'(test|-o|-a)\s*[^\s]+\s+==\s', # should be 'b = a'
    qr'\[\s+[^\]]+\s+==\s',        # should be 'b = a'
    qr'\s(\|\&)',                        # pipelining is not POSIX
    qr'[^\\\$]\{(?:[^\s\\\}]*?,)+[^\\\}\s]*\}', # brace expansion
    qr'(?:^|\s+)\w+\[\d+\]=',      # bash arrays, H[0]
    $LEADIN . qr'read\s+(?:-[a-qs-zA-Z\d-]+)',
    # read with option other than -r
    $LEADIN . qr'read\s*(?:-\w+\s*)*(?:\".*?\"|[\'].*?[\'])?\s*(?:;|$)',
    # read without variable
    qr'\&>',                     # cshism
    qr'(<\&|>\&)\s*((-|\d+)[^\s;|)`&\\\\]|[^-\d\s]+)', # should be >word 2>&1
    qr'\[\[(?!:)',               # alternative test command
    $LEADIN . qr'select\s+\w+',    # 'select' is not POSIX
    $LEADIN . qr'echo\s+(-n\s+)?-n?en?',  # echo -e
    $LEADIN . qr'exec\s+-[acl]',   # exec -c/-l/-a name
    qr'(?:^|\s+)let\s',          # let ...
    qr'(?<![\$\(])\(\(.*\)\)',     # '((' should be '$(('
    qr'\$\[[^][]+\]',            # '$[' should be '$(('
    qr'(\[|test)\s+-a',          # test with unary -a (should be -e)
    qr'/dev/(tcp|udp)',          # /dev/(tcp|udp)
    $LEADIN . qr'\w+\+=',                # should be "VAR="${VAR}foo"
    $LEADIN . qr'suspend\s',
    $LEADIN . qr'caller\s',
    $LEADIN . qr'complete\s',
    $LEADIN . qr'compgen\s',
    $LEADIN . qr'declare\s',
    $LEADIN . qr'typeset\s',
    $LEADIN . qr'disown\s',
    $LEADIN . qr'builtin\s',
    $LEADIN . qr'set\s+-[BHT]+',   # set -[BHT]
    $LEADIN . qr'alias\s+-p',      # alias -p
    $LEADIN . qr'unalias\s+-a',    # unalias -a
    $LEADIN . qr'local\s+-[a-zA-Z]+', # local -opt
    qr'(?:^|\s+)\s*\(?\w*[^\(\w\s]+\S*?\s*\(\)\s*([\{|\(]|\Z)',
    # function names should only contain [a-z0-9_]
    $LEADIN . qr'(push|pop)d(\s|\Z)',   # (push|pod)d
    $LEADIN . qr'export\s+-[^p]',  # export only takes -p as an option
    $LEADIN . qr'ulimit(\s|\Z)',
    $LEADIN . qr'shopt(\s|\Z)',
    $LEADIN . qr'type\s',
    $LEADIN . qr'time\s',
    $LEADIN . qr'dirs(\s|\Z)',
    qr'(?:^|\s+)[<>]\(.*?\)',      # <() process substitution
    qr'(?:^|\s+)readonly\s+-[af]', # readonly -[af]
    $LEADIN . qr'(sh|\$\{?SHELL\}?) -[rD]', # sh -[rD]
    $LEADIN . qr'(sh|\$\{?SHELL\}?) --\w+', # sh --long-option
    $LEADIN . qr'(sh|\$\{?SHELL\}?) [-+]O', # sh [-+]O
);

# a local function to help use separate tags for example scripts
sub script_tag {
    my($self, $tag, $filename, @rest) = @_;

    $tag = "example-$tag"
      if $filename and $filename =~ m,usr/share/doc/[^/]+/examples/,;

    $self->tag(($tag, $filename, @rest));
    return;
}

sub installable {
    my ($self) = @_;

    my $pkg = $self->package;
    my $processable = $self->processable;

    my (%executable, %ELF, %scripts, %seen_helper_cmds);

    # no dependency for install-menu, because the menu package specifically
    # says not to depend on it.

    foreach my $file ($processable->installed->sorted_list) {
        next if not $file->is_file;
        $ELF{$file} = 1 if $file->file_info =~ /^[^,]*\bELF\b/;
        next unless $file->operm & 0111;
        $executable{$file} = 1;
    }

    my $all_parsed = Lintian::Relation->and($processable->relation('all'),
        $processable->relation('provides'),$pkg);
    my $str_deps = $processable->relation('strong');

    my @x11_fonts
      = grep {m,^usr/share/fonts/X11/.*\.(?:afm|pcf|pfa|pfb)(?:\.gz)?$,}
      $processable->installed->sorted_list;

    my %old_versions;
    for my $entry (
        $processable->changelog
        ? @{$processable->changelog->entries}
        : ()
    ) {
        my $timestamp = $entry->Timestamp // $OLDSTABLE_RELEASE;
        $old_versions{$entry->Version} = $timestamp
          if $timestamp < $OLDSTABLE_RELEASE;
    }

    for my $file ($processable->installed->sorted_list) {

        next
          unless $file->is_script;

        my $interpreter = $file->script->{interpreter};
        my $calls_env = $file->script->{calls_env};

        my $filename = $file->name;
        my $path;
        $scripts{$filename} = 1;

        # Consider /usr/src/ scripts as "documentation"
        # - packages containing /usr/src/ tend to be "-source" .debs
        #   and usually comes with overrides for most of the checks
        #   below.
        # Supposedly, they could be checked as examples, but there is
        # a risk that the scripts need substitution to be complete
        # (so, syntax checking is not as reliable).
        my $in_docs = $filename =~ m,^usr/(?:share/doc|src)/,;
        my $in_examples = $filename =~ m,^usr/share/doc/[^/]+/examples/,;

        # no checks necessary at all for scripts in /usr/share/doc/
        # unless they are examples
        next
          if $in_docs && !$in_examples;

        my ($base) = $interpreter =~ m,([^/]*)$,;

        # Ignore Python scripts that are shipped under dist-packages; these
        # files aren't supposed to be called as scripts.
        next
          if $base eq 'python'
          and $filename =~ m,^usr/lib/python3/dist-packages/,;

        # allow exception for .in files that have stuff like #!@PERL@
        next
          if (  $filename =~ m,\.in$,
            and $interpreter =~ m,^(\@|<\<)[A-Z_]+(\@|>\>)$,);

        my $is_absolute = ($interpreter =~ m,^/, or $calls_env);

        # As a special-exception, Policy 10.4 states that Perl scripts must use
        # /usr/bin/perl directly and not via /usr/bin/env, etc.
        $self->script_tag(bad_interpreter_tag_name('/usr/bin/env perl'),
            $filename, '(#!/usr/bin/env perl != /usr/bin/perl)')
          if $calls_env and $interpreter eq 'perl';

        # Skip files that have the #! line, but are not executable and
        # do not have an absolute path and are not in a bin/ directory
        # (/usr/bin, /bin etc).  They are probably not scripts after
        # all.
        next
          if ( $filename !~ m,(?:bin/|etc/init\.d/),
            && !$executable{$filename}
            && !$is_absolute
            && !$in_examples);

        # Example directories sometimes contain Perl libraries, and
        # some people use initial lines like #!perl or #!python to
        # provide editor hints, so skip those too if they're not
        # executable.  Be conservative here, since it's not uncommon
        # for people to both not set examples executable and not fix
        # the path and we want to warn about that.
        next
          if ( $filename =~ /\.pm\z/
            && !$executable{$filename}
            && !$is_absolute
            && $in_examples);

        # Skip upstream source code shipped in /usr/share/cargo/registry/
        next
          if $filename =~ m,^usr/share/cargo/registry/,;

        if ($interpreter eq '') {
            $self->script_tag('script-without-interpreter', $filename);
            next;
        }

        # Either they use an absolute path or they use '/usr/bin/env interp'.
        $self->script_tag('interpreter-not-absolute', $filename,
            "#!$interpreter")
          unless $is_absolute;

        my $bash_completion_regex
          = qr{^usr/share/bash-completion/completions/.*};

        $self->tag('script-not-executable', $filename)
          unless (
               $executable{$filename}
            or $filename =~ m,^usr/(?:lib|share)/.*\.pm,
            or $filename =~ m,^usr/(?:lib|share)/.*\.py,
            or $filename =~ m,^usr/(?:lib|share)/ruby/.*\.rb,
            or $filename =~ m,^usr/share/debconf/confmodule(?:\.sh)?$,
            or $filename =~ m,\.in$,
            or $filename =~ m,\.erb$,
            or $filename =~ m,\.ex$,
            or $filename eq 'etc/init.d/skeleton'
            or $filename =~ m,^etc/menu-methods,
            or $filename =~ $bash_completion_regex,
            or $filename =~ m,^etc/X11/Xsession\.d,
          )or $in_docs;

        # for bash completion issue this instead
        $self->tag('bash-completion-with-hashbang', $filename)
          if $filename =~ $bash_completion_regex;

        # Warn about csh scripts.
        $self->tag('csh-considered-harmful', $filename)
          if (  ($base eq 'csh' or $base eq 'tcsh')
            and $executable{$filename}
            and $filename !~ m,^etc/csh/login\.d/,)
          and not $in_docs;

        next
          unless $file->is_open_ok;
        # Syntax-check most shell scripts, but don't syntax-check
        # scripts that end in .dpatch.  bash -n doesn't stop checking
        # at exit 0 and goes on to blow up on the patch itself.
        if ($base =~ /^$known_shells_regex$/) {
            if (
                    -x $interpreter
                and not script_is_evil_and_wrong($file)
                and $filename !~ m,\.dpatch$,
                and $filename !~ m,\.erb$,
                # exclude some shells. zsh -n is broken, see #485885
                and $base !~ m/^(?:z|t?c)sh$/
            ) {

                if (check_script_syntax($interpreter, $file)) {
                    $self->script_tag('shell-script-fails-syntax-check',
                        $filename);
                }
            }
        }

        # Try to find the expected path of the script to check.  First
        # check $INTERPRETERS and %versioned_interpreters.  If not
        # found there, see if it ends in a version number and the base
        # is found in $VERSIONED_INTERPRETERS
        my $data = $INTERPRETERS->value($base);
        my $versioned = 0;
        if (not defined $data) {
            $data = $VERSIONED_INTERPRETERS->value($base);
            undef $data if ($data and not defined($data->[1]));
            if (not defined($data) and $base =~ /^(.*[^\d.-])-?[\d.]+$/) {
                $data = $VERSIONED_INTERPRETERS->value($1);
                undef $data unless ($data and $base =~ /$data->[2]/);
            }
            $versioned = 1 if $data;
        }
        if ($data) {
            my $expected = $data->[0] . '/' . $base;
            unless ($interpreter eq $expected or $calls_env) {
                $self->script_tag(bad_interpreter_tag_name($expected),
                    $filename, "(#!$interpreter != $expected)");
            }
        } elsif ($interpreter =~ m,/usr/local/,) {
            $self->script_tag('interpreter-in-usr-local', $filename,
                "#!$interpreter");
        } elsif ($interpreter eq '/bin/env') {
            $self->script_tag('script-uses-bin-env', $filename);
        } elsif ($interpreter eq 'nodejs') {
            $self->script_tag('script-uses-deprecated-nodejs-location',
                $filename);
            # Check whether we have correct dependendies on nodejs regardless.
            $data = $INTERPRETERS->value('node');
        } elsif ($base =~ /^php/) {
            $self->script_tag('php-script-with-unusual-interpreter',
                $filename, "$interpreter");

            # This allows us to still perform the dependencies checks
            # below even when an unusual interpreter has been found.
            $data = $INTERPRETERS->value('php');
        } else {
            my $pinter = 0;
            if ($interpreter =~ m,^/,) {
                # Check if the package ships the interpreter (and it is
                # executable).
                my $interfile = substr $interpreter, 1;
                $pinter = 1 if $executable{$interfile};
            } elsif ($calls_env) {
                for my $dir (qw(usr/bin bin)) {
                    if ($executable{"$dir/$interpreter"}) {
                        $pinter = 1;
                        last;
                    }
                }
            }
            $self->script_tag('unusual-interpreter', $filename,
                "#!$interpreter")
              unless $pinter;

        }

        # Check for obsolete perl libraries
        if (
            $base eq 'perl'
            &&!$str_deps->implies(
                'libperl4-corelibs-perl | perl (<< 5.12.3-7)')
        ) {
            open(my $fd, '<', $file->unpacked_path);
            while (<$fd>) {
                if (
                    m{ (?:do|require)\s+['"] # do/require

                          # Huge list of perl4 modules...
                          (abbrev|assert|bigfloat|bigint|bigrat
                          |cacheout|complete|ctime|dotsh|exceptions
                          |fastcwd|find|finddepth|flush|getcwd|getopt
                          |getopts|hostname|importenv|look|newgetopt
                          |open2|open3|pwd|shellwords|stat|syslog
                          |tainted|termcap|timelocal|validate)
                          # ... so they end with ".pl" rather than ".pm"
                          \.pl['"]
               }xsm
                ) {
                    $self->tag('script-uses-perl4-libs-without-dep',
                        "$filename:$. ${1}.pl");
                }
            }
            close($fd);
        }

        # If we found the interpreter and the script is executable,
        # check dependencies.  This should be the last thing we do in
        # the loop so that we can use next for an early exit and
        # reduce the nesting.
        next unless ($data and $executable{$filename} and not $in_docs);
        if (!$versioned) {
            my $depends = $data->[1];
            if (not defined $depends) {
                $depends = $base;
            }
            if ($depends && !$all_parsed->implies($depends)) {
                if ($base =~ /^php/) {
                    $self->tag('php-script-but-no-php-cli-dep',
                        $filename,"#!$interpreter");
                } elsif ($base =~ /^(python|ruby|[mg]awk)$/) {
                    $self->tag((
                        "$base-script-but-no-$base-dep",$filename,
                        "#!$interpreter"
                    ));
                } elsif ($base eq 'csh' && $filename =~ m,^etc/csh/login\.d/,){
                    # Initialization files for csh.
                } elsif ($base eq 'fish' && $filename =~ m,^etc/fish\.d/,) {
                    # Initialization files for fish.
                } elsif (
                    $base eq 'ocamlrun'
                    && $all_parsed->matches(
                        qr/^ocaml(?:-base)?(?:-nox)?-\d\.[\d.]+/)
                ) {
                    # ABI-versioned virtual packages for ocaml
                } elsif ($base eq 'escript'
                    && $all_parsed->matches(qr/^erlang-abi-[\d+\.]+$/)) {
                    # ABI-versioned virtual packages for erlang
                } else {
                    $self->tag(
                        'missing-dep-for-interpreter', "$base => $depends",
                        "($filename)", "#!$interpreter"
                    );
                }
            }
        } elsif ($VERSIONED_INTERPRETERS->known($base)) {
            my @versions = @{ $data->[4] };
            my @depends = map {
                my $d = $data->[3];
                $d =~ s/\$1/$_/g;
                $d;
            } @versions;
            unshift(@depends, $data->[1]) if length $data->[1];
            my $depends = join(' | ',  @depends);
            unless ($all_parsed->implies($depends)) {
                if ($base =~ /^(wish|tclsh)/) {
                    $self->tag("$1-script-but-no-$1-dep", $filename,
                        "#!$interpreter");
                } else {
                    $self->tag(
                        'missing-dep-for-interpreter', "$base => $depends",
                        "($filename)", "#!$interpreter"
                    );
                }
            }
        } else {
            my ($version) = ($base =~ /$data->[2]/);
            my $depends = $data->[3];
            $depends =~ s/\$1/$version/g;
            unless ($all_parsed->implies($depends)) {
                if ($base =~ /^(python|ruby)/) {
                    $self->tag("$1-script-but-no-$1-dep", $filename,
                        "#!$interpreter");
                } else {
                    $self->tag(
                        'missing-dep-for-interpreter', "$base => $depends",
                        "($filename)", "#!$interpreter"
                    );
                }
            }
        }
    }

    for my $name (keys %executable) {
        my $file = $processable->installed->lookup($name);
        my $ok = 0;
        if ($file->is_hardlink) {
            # We don't collect script information for hardlinks, so check
            # if the target is a script.
            my $targetname = $file->link_normalized;
            my $target = $processable->installed->lookup($targetname);

            $ok = 1
              if $target->is_script;
        }

        $self->tag('executable-not-elf-or-script', $name)
          unless (
               $ok
            or $ELF{$name}
            or $scripts{$name}
            or $name =~ m,^usr(?:/X11R6)?/man/,
            or $name =~ m/\.exe$/ # mono convention
            or $name =~ m/\.jar$/ # Debian Java policy 2.2
          );
    }

    # get maintainer scripts
    my @control
      = grep { $_->is_control } $self->processable->control->sorted_list;

    # Handle control scripts.  This is an edited version of the code for
    # normal scripts above, because there were just enough differences to
    # make a shared function awkward.

    my (%added_diversions, %removed_diversions);
    my $expand_diversions = 0;
    for my $file (@control) {

        my $interpreter = $file->control->{interpreter};

        $interpreter =~ m|([^/]*)$|;
        my $base = $1;

        # tag for statistics
        $self->tag('maintainer-script-interpreter',
            "control/$file", $interpreter);

        if ($interpreter eq '') {
            $self->tag('script-without-interpreter', "control/$file");
            next;
        }

        if ($interpreter eq 'ELF') {
            $self->tag('elf-maintainer-script', "control/$file");
            next;
        }

        $self->tag('interpreter-not-absolute', "control/$file",
            "#!$interpreter")
          unless ($interpreter =~ m|^/|);

        if ($interpreter =~ m|/usr/local/|) {
            $self->tag('control-interpreter-in-usr-local',
                "control/$file","#!$interpreter");
        } elsif ($base eq 'sh' or $base eq 'bash' or $base eq 'perl') {
            my $expected = ($INTERPRETERS->value($base))->[0] . '/' . $base;
            $self->tag(
                bad_interpreter_tag_name($expected),
                "#!$interpreter != $expected",
                "(control/$file)"
            ) unless $interpreter eq $expected;
        } elsif ($file eq 'config') {
            $self->tag('forbidden-config-interpreter', "#!$interpreter");
        } elsif ($file eq 'postrm') {
            $self->tag('forbidden-postrm-interpreter', "#!$interpreter");
        } elsif ($INTERPRETERS->known($base)) {
            my $data = $INTERPRETERS->value($base);
            my $expected = $data->[0] . '/' . $base;
            unless ($interpreter eq $expected) {
                $self->tag(
                    bad_interpreter_tag_name($expected),
                    "#!$interpreter != $expected",
                    "(control/$file)"
                );
            }
            $self->tag('unusual-control-interpreter', "control/$file",
                "#!$interpreter");

            # Interpreters used by preinst scripts must be in
            # Pre-Depends.  Interpreters used by postinst or prerm
            # scripts must be in Depends.
            unless (not $data->[1]) {
                my $depends = Lintian::Relation->new($data->[1]);
                if ($file eq 'preinst') {
                    unless ($processable->relation('pre-depends')
                        ->implies($depends)){
                        $self->tag('preinst-interpreter-without-predepends',
                            "#!$interpreter");
                    }
                } else {
                    unless (
                        $processable->relation('strong')->implies($depends)) {
                        $self->tag(
                            'control-interpreter-without-depends',
                            "control/$file",
                            "#!$interpreter"
                        );
                    }
                }
            }
        } else {
            $self->tag('unknown-control-interpreter', "control/$file",
                "#!$interpreter");
            next; # no use doing further checks if it's not a known interpreter
        }

        # perhaps we should warn about *csh even if they're somehow screwed,
        # but that's not really important...
        $self->tag('csh-considered-harmful', "control/$file")
          if ($base eq 'csh' or $base eq 'tcsh');

        next
          unless $file->is_open_ok;

        my $shellscript = $base =~ /^$known_shells_regex$/ ? 1 : 0;

        # Only syntax-check scripts we can check with bash.
        my $checkbashisms;
        if ($shellscript) {
            $checkbashisms = $base eq 'sh' ? 1 : 0;
            if ($base eq 'sh' or $base eq 'bash') {
                if (check_script_syntax("/bin/${base}", $file)) {
                    $self->tag('maintainer-shell-script-fails-syntax-check',
                        $file);
                }
            }
        }

        # now scan the file contents themselves
        open(my $fd, '<', $file->unpacked_path);

        my (
            $saw_init, $saw_invoke,
            $saw_debconf,$saw_bange,
            $saw_sete, $has_code,
            $saw_statoverride_list, $saw_statoverride_add,
            $saw_udevadm_guard, $saw_update_fonts
        );
        my %warned;
        my $cat_string = '';

        my $previous_line = '';
        my $in_automatic_section = 0;
        while (<$fd>) {
            if ($. == 1 && $shellscript && m,/$base\s*.*\s-\w*e\w*\b,) {
                $saw_bange = 1;
            }

            if (/\#DEBHELPER\#/) {
                $self->tag('maintainer-script-has-unexpanded-debhelper-token',
                    $file);
            }

            $in_automatic_section = 1
              if /^# Automatically added by \S+\s*$/;

            $in_automatic_section = 0
              if $_ eq '# End automatically added section';

            # skip empty lines
            next
              if m,^\s*$,;

            # skip comment lines
            next
              if m,^\s*\#,;
            $_ = remove_comments($_);

            # Concatenate lines containing continuation character (\)
            # at the end
            if ($shellscript && /\\$/) {
                s/\\//;
                chomp;
                $previous_line .= $_;
                next;
            }

            chomp;
            $_ = $previous_line . $_;
            $previous_line = '';

            # Don't consider the standard dh-make boilerplate to be code.  This
            # means ignoring the framework of a case statement, the labels, the
            # echo complaining about unknown arguments, and an exit.
            unless ($has_code
                || m/^\s*set\s+-\w+\s*$/
                || m/^\s*case\s+\"?\$1\"?\s+in\s*$/
                || m/^\s*(?:[a-z|-]+|\*)\)\s*$/
                || m/^\s*[:;]+\s*$/
                || m/^\s*echo\s+\"[^\"]+\"(?:\s*>&2)?\s*$/
                || m/^\s*esac\s*$/
                || m/^\s*exit\s+\d+\s*$/) {
                $has_code = 1;
            }

            if ($shellscript
                && m,${LEADIN}set\s*(?:\s+-(?:-.*|[^e]+))*\s-\w*e,) {
                $saw_sete = 1;
            }

            if (m,$LEADIN(?:/usr/bin/)?dpkg-statoverride\s,) {
                $saw_statoverride_add = $. if /--add/;
                $saw_statoverride_list = 1 if /--list/;
            }

            if (m,$LEADIN(?:/usr/bin/)?dpkg-maintscript-helper\s(\S+),) {
                my $cmd = $1;
                $seen_helper_cmds{$cmd} = () unless $seen_helper_cmds{$cmd};
                $seen_helper_cmds{$cmd}{$file} = 1;
            }

            $saw_update_fonts = 1
              if
              m,$LEADIN(?:/usr/bin/)?update-fonts-(?:alias|dir|scale)\s(\S+),;

            $saw_udevadm_guard = 1 if m/\b(if|which|command)\s+.*udevadm/g;
            if (m,$LEADIN(?:/bin/)?udevadm\s, and $saw_sete) {
                $self->tag('udevadm-called-without-guard', "$file:$.")
                  unless $saw_udevadm_guard
                  or m/\|\|/
                  or $str_deps->implies('udev');
            }

            if (    m,[^\w](?:(?:/var)?/tmp|\$TMPDIR)/[^)\]}\s],
                and not m/\bmks?temp\b/
                and not m/\btempfile\b/
                and not m/\bmkdir\b/
                and not m/\bXXXXXX\b/
                and not m/\$RANDOM/) {
                $self->tag(
'possibly-insecure-handling-of-tmp-files-in-maintainer-script',
                    "$file:$."
                ) unless $warned{tmp};
                $warned{tmp} = 1;
            }
            if (m/^\s*killall(?:\s|\z)/) {
                $self->tag('killall-is-dangerous', "$file:$.")
                  unless $warned{killall};
                $warned{killall} = 1;
            }
            if (m/^\s*mknod(?:\s|\z)/ and not m/\sp\s/) {
                $self->tag('mknod-in-maintainer-script', "$file:$.");
            }

            # Collect information about init script invocations to
            # catch running init scripts directly rather than through
            # invoke-rc.d.  Since the script is allowed to run the
            # init script directly if invoke-rc.d doesn't exist, only
            # tag direct invocations where invoke-rc.d is never used
            # in the same script.  Lots of false negatives, but
            # hopefully not many false positives.
            if (m%^\s*/etc/init\.d/(?:\S+)\s+[\"\']?(?:\S+)[\"\']?%) {
                $saw_init = $.;
            }
            if (m%^\s*invoke-rc\.d\s+%) {
                $saw_invoke = $.;
            }

            if ($shellscript) {
                if ($cat_string ne '' and m/^\Q$cat_string\E$/) {
                    $cat_string = '';
                }
                my $within_another_shell = 0;
                if (
                    m{
                      (?:^|\s+)(?:(?:/usr)?/bin/)?
                      ($known_shells_regex)\s+-c\s*.+
                    }xsm
                    and $1 ne 'sh'
                ) {
                    $within_another_shell = 1;
                }
                # if cat_string is set, we are in a HERE document and need not
                # check for things
                if (   $cat_string eq ''
                    && $checkbashisms
                    && !$within_another_shell) {
                    my $found = 0;
                    my $match = '';

                 # since this test is ugly, I have to do it by itself
                 # detect source (.) trying to pass args to the command it runs
                 # The first expression weeds out '. "foo bar"'
                    if (
                            not $found
                        and not m{\A \s*\.\s+
                                   (?:\"[^\"]+\"|\'[^\']+\')\s*
                                   (?:\&|\||\d?>|<|;|\Z)}xsm
                        and m/^\s*(\.\s+[^\s;\`:]+\s+([^\s;]+))/
                    ) {

                        my $extra;
                        ($match, $extra) = ($1, $2);
                        if ($extra =~ /^(\&|\||\d?>|<)/) {
                            # everything is ok
                            ;
                        } else {
                            $found = 1;
                        }
                    }

                    my $line = $_;

                    unless ($found) {
                        for my $re (@bashism_single_quote_regexs) {
                            if ($line =~ m/($re)/) {
                                $found = 1;
                                ($match) = m/($re)/;
                                last;
                            }
                        }
                    }

                    # Ignore anything inside single quotes; it could be an
                    # argument to grep or the like.

                    # $cat_line contains the version of the line we'll check
                    # for heredoc delimiters later. Initially, remove any
                    # spaces between << and the delimiter to make the following
                    # updates to $cat_line easier.
                    my $cat_line = $line;
                    $cat_line =~ s/(<\<-?)\s+/$1/g;

                    # Remove single quoted strings, with the exception
                    # that we don't remove the string
                    # if the quote is immediately preceded by a < or
                    # a -, so we can match "foo <<-?'xyz'" as a
                    # heredoc later The check is a little more greedy
                    # than we'd like, but the heredoc test itself will
                    # weed out any false positives
                    $cat_line
                      =~ s/(^|[^<\\\"-](?:\\\\)*)\'(?:\\.|[^\\\'])+\'/$1''/g;

                    unless ($found) {
                        # Remove "quoted quotes". They're likely to be
                        # inside another pair of quotes; we're not
                        # interested in them for their own sake and
                        # removing them makes finding the limits of
                        # the outer pair far easier.
                        $line =~ s/(^|[^\\\'\"])\"\'\"/$1/g;
                        $line =~ s/(^|[^\\\'\"])\'\"\'/$1/g;

                        $line
                          =~ s/(^|[^\\\"](?:\\\\)*)\'(?:\\.|[^\\\'])+\'/$1''/g;
                        for my $re (@bashism_string_regexs) {
                            if ($line =~ m/($re)/) {
                                $found = 1;
                                ($match) = m/($re)/;
                                last;
                            }
                        }
                    }

                    # We've checked for all the things we still want
                    # to notice in double-quoted strings, so now
                    # remove those strings as well.
                    $cat_line
                      =~ s/(^|[^<\\\'-](?:\\\\)*)\"(?:\\.|[^\\\"])+\"/$1""/g;
                    unless ($found) {
                        $line
                          =~ s/(^|[^\\\'](?:\\\\)*)\"(?:\\.|[^\\\"])+\"/$1""/g;
                        for my $re (@bashism_regexs) {
                            if ($line =~ m/($re)/) {
                                $found = 1;
                                ($match) = m/($re)/;
                                last;
                            }
                        }
                    }

                    if ($found) {
                        $self->tag('possible-bashism-in-maintainer-script',
                            "$file:$. \'$match\'");
                    }

                    # Only look for the beginning of a heredoc here,
                    # after we've stripped out quoted material, to
                    # avoid false positives.
                    if ($cat_line
                        =~ m/(?:^|[^<])\<\<\-?\s*(?:[\\]?(\w+)|[\'\"](.*?)[\'\"])/
                    ) {
                        $cat_string = $1;
                        $cat_string = $2 if not defined $cat_string;
                    }
                }
                if (!$cat_string) {
                    $self->generic_check_bad_command($_, $file, $., 0,
                        $in_automatic_section);

                    if (m,/usr/share/debconf/confmodule,) {
                        $saw_debconf = 1;
                    }
                    if (m/^\s*read(?:\s|\z)/ && !$saw_debconf) {
                        $self->tag('read-in-maintainer-script', "$file:$.");
                    }

                    $self->tag('multi-arch-same-package-calls-pycompile',
                        "$file:$.")
                      if m/^\s*py3?compile(?:\s|\z)/
                      and $processable->field('multi-arch', 'no') eq 'same';

                    if (m,>\s*/etc/inetd\.conf(?:\s|\Z),) {
                        $self->tag('maintainer-script-modifies-inetd-conf',
                            "$file:$.")
                          unless $processable->relation('provides')
                          ->implies('inet-superserver');
                    }
                    if (m,^\s*(?:cp|mv)\s+(?:.*\s)?/etc/inetd\.conf\s*$,) {
                        $self->tag('maintainer-script-modifies-inetd-conf',
                            "$file:$.")
                          unless $processable->relation('provides')
                          ->implies('inet-superserver');
                    }

                    # Check for running commands with a leading path.
                    #
                    # Unfortunately, our $LEADIN string doesn't work
                    # well for this in the presence of commands that
                    # contain backquoted expressions because it can't
                    # tell the difference between the initial backtick
                    # and the closing backtick.  We therefore first
                    # extract all backquoted expressions and check
                    # them separately, and then remove them from a
                    # copy of a string and then check it for bashisms.
                    while (m,\`([^\`]+)\`,g) {
                        my $cmd = $1;
                        if (
                            $cmd =~ m{ $LEADIN
                                      (/(?:usr/)?s?bin/[\w.+-]+)
                                      (?:\s|;|\Z)}xsm
                        ) {
                            $self->tag(
                                'command-with-path-in-maintainer-script',
                                "$file:$. $1")
                              unless $in_automatic_section;
                        }
                    }
                    my $cmd = $_;
                    # check for test syntax
                    if(
                        $cmd =~ m{\[\s+
                          (?:!\s+)? -x \s+
                          (/(?:usr/)?s?bin/[\w.+-]+)
                          \s+ \]}xsm
                    ){
                        $self->tag('command-with-path-in-maintainer-script',
                            "$file:$. $1")
                          unless $in_automatic_section;
                    }

                    $cmd =~ s/\`[^\`]+\`//g;
                    if ($cmd =~ m,$LEADIN(/(?:usr/)?s?bin/[\w.+-]+)(?:\s|;|$),)
                    {
                        $self->tag('command-with-path-in-maintainer-script',
                            "$file:$. $1")
                          unless $in_automatic_section;
                    }
                }
            }
            unless ($file eq 'postrm') {
                for my $rule (@depends_needed) {
                    my ($package, $regex) = @$rule;
                    if (    $pkg ne $package
                        and /$regex/
                        and not $warned{$package}) {
                        if (   m,-x\s+\S*$regex,
                            or m,(?:which|type)\s+$regex,
                            or m,command\s+.*?$regex,) {
                            $warned{$package} = 1;
                        } elsif (!/\|\|\s*true\b/) {
                            unless ($processable->relation('strong')
                                ->implies($package)) {
                                my $shortpackage = $package;
                                $shortpackage =~ s/[ \(].*//;
                                $self->tag(
"maintainer-script-needs-depends-on-$shortpackage",
                                    $file
                                );
                                $warned{$package} = 1;
                            }
                        }
                    }
                }
            }

            $self->generic_check_bad_command($_, $file, $., 1,
                $in_automatic_section);

            for my $ver (sort keys %old_versions) {
                next if $ver =~ /^\d+$/;
                if (
m,$LEADIN(?:/usr/bin/)?dpkg\s+--compare-versions\s+.*\b\Q$ver\E(?!\.)\b,
                ) {
                    my $date= strftime('%Y-%m-%d', gmtime $old_versions{$ver});
                    my $epoch= strftime('%Y-%m-%d', gmtime $OLDSTABLE_RELEASE);
                    $self->tag(
                        'maintainer-script-supports-ancient-package-version',
                        "$file:$.", $ver, "($date < $epoch)");
                    last;
                }
            }

            if (m,$LEADIN(?:/usr/sbin/)?update-inetd\s,) {
                $self->tag(
                    'maintainer-script-has-invalid-update-inetd-options',
                    "$file:$.", '(--pattern with --add)')
                  if /--pattern/ && /--add/;
                $self->tag(
                    'maintainer-script-has-invalid-update-inetd-options',
                    "$file:$.", '(--group without --add)')
                  if /--group/ && !/--add/;
            }

            my $pdepends = $processable->relation('pre-depends');
            $self->tag('skip-systemd-native-flag-missing-pre-depends',
                "$file:$.")
              if m/invoke-rc.d\b.*--skip-systemd-native\b/
              && !$pdepends->implies('init-system-helpers (>= 1.54~)');

            my $depends = $processable->relation('depends');
            $self->tag(
                'missing-versioned-depends-on-init-system-helpers',
                "$file:$.",
                "\"$1 $2\" needs init-system-helpers >= 1.50"
              )
              if m/(update-rc\.d)\b.*(defaults-disabled)\b/
              && !$depends->implies('init-system-helpers (>= 1.50)');

            if (m,$LEADIN(?:/usr/sbin/)?dpkg-divert\s,
                && !/--(?:help|list|truename|version)/) {
                if (/--local/) {
                    $self->tag('package-uses-local-diversion', "$file:$.");
                }
                my $mode = /--remove/ ? 'remove' : 'add';
                my ($divert) = /dpkg-divert\s*(.*)$/;
                $divert =~ s{\s*(?:\$[{]?[\w:=-]+[}]?)*\s*
                                # options without arguments
                              --(?:add|quiet|remove|rename|test|local
                                # options with arguments
                                |(?:admindir|divert|package) \s+ \S+)
                              \s*}{}gxsm;
                # Remove unpaired opening or closing parenthesis
                1 while ($divert =~ m/\G.*?\(.+?\)/gc);
                $divert =~ s/\G(.*?)[()]/$1/;
                pos($divert) = undef;
                # Remove unpaired opening or closing braces
                1 while ($divert =~ m/\G.*?{.+?}/gc);
                $divert =~ s/\G(.*?)[{}]/$1/;
                pos($divert) = undef;

                # position after the last pair of quotation marks, if any
                1 while ($divert =~ m/\G.*?(["']).+?\1/gc);
                # Strip anything matching and after '&&', '||', ';', or '>'
                # this is safe only after we are positioned after the last pair
                # of quotation marks
                $divert =~ s/\G.+?\K(?: && | \|\| | ; | \d*> ).*$//x;
                pos($divert) = undef;
                # Remove quotation marks, they affect:
                # * our var to regex trick
                # * stripping the initial slash if the path was quoted
                $divert =~ s/[\"\']//g;
                # remove the leading / because it's not in the index hash
                $divert =~ s,^/,,;

                # trim both ends
                $divert =~ s/^\s+|\s+$//g;

                $divert = quotemeta($divert);

                # For now just replace variables, they will later be normalised
                $expand_diversions = 1 if $divert =~ s/\\\$\w+/.+/g;
                $expand_diversions = 1
                  if $divert =~ s/\\\$\\[{]\w+.*?\\[}]/.+/g;
                # handle $() the same way:
                $expand_diversions = 1 if $divert =~ s/\\\$\\\(.+?\\\)/.+/g;

                if ($mode eq 'add') {
                    $added_diversions{$divert}
                      = {'script' => $file, 'line' => $.};
                } elsif ($mode eq 'remove') {
                    push @{$removed_diversions{$divert}},
                      {'script' => $file, 'line' => $.};
                } else {
                    die "\$mode has unknown value: $mode";
                }
            }
        }

        foreach my $font (@x11_fonts) {
            $self->tag('missing-call-to-update-fonts', $font)
              if $file eq 'postinst' and not $saw_update_fonts;
        }

        if ($saw_init && !$saw_invoke) {
            $self->tag('maintainer-script-calls-init-script-directly',
                "$file:$saw_init");
        }
        unless ($has_code) {
            $self->tag('maintainer-script-empty', $file);
        }
        if ($shellscript && !$saw_sete) {
            if ($saw_bange) {
                $self->tag('maintainer-script-without-set-e', $file);
            } else {
                $self->tag('maintainer-script-ignores-errors', $file);
            }
        }

        if ($saw_statoverride_add && !$saw_statoverride_list) {
            $self->tag('unconditional-use-of-dpkg-statoverride',
                "$file:$saw_statoverride_add");
        }

        close($fd);

    }

    for my $cmd (qw(rm_conffile mv_conffile symlink_to_dir)) {
        next unless $seen_helper_cmds{$cmd};

        # dpkg-maintscript-helper(1) recommends the snippets are in all
        # maintainer scripts but they are not strictly required in prerm.
        for my $file (qw(preinst postinst postrm)) {
            $self->tag('missing-call-to-dpkg-maintscript-helper',
                "$file ($cmd)")
              unless $seen_helper_cmds{$cmd}{$file};
        }
    }

    # If any of the maintainer scripts used a variable in the file or
    # diversion name normalise them all
    if ($expand_diversions) {
        for my $divert (keys %removed_diversions, keys %added_diversions) {

            # if a wider regex was found, the entries might no longer be there
            unless (exists($removed_diversions{$divert})
                or exists($added_diversions{$divert})) {
                next;
            }

            my $widerrx = $divert;
            my $wider = $widerrx;
            $wider =~ s/\\//g;

            # find the widest regex:
            my @matches = grep {
                my $lrx = $_;
                my $l = $lrx;
                $l =~ s/\\//g;

                if ($wider =~ m/^$lrx$/) {
                    $widerrx = $lrx;
                    $wider = $l;
                    1;
                } elsif ($l =~ m/^$widerrx$/) {
                    1;
                } else {
                    0;
                }
            } (keys %removed_diversions, keys %added_diversions);

            # replace all the occurrences with the widest regex:
            for my $k (@matches) {
                next if ($k eq $widerrx);

                if (exists($removed_diversions{$k})) {
                    $removed_diversions{$widerrx} = $removed_diversions{$k};
                    delete $removed_diversions{$k};
                }
                if (exists($added_diversions{$k})) {
                    $added_diversions{$widerrx} = $added_diversions{$k};
                    delete $added_diversions{$k};
                }
            }
        }
    }

    for my $divert (keys %removed_diversions) {
        if (exists $added_diversions{$divert}) {
            # just mark the entry, because a --remove might
            # happen in two branches in the script, i.e. we
            # see it twice, which is not a bug
            $added_diversions{$divert}{'removed'} = 1;
        } else {
            for my $item (@{$removed_diversions{$divert}}) {
                my $script = $item->{'script'};
                my $line = $item->{'line'};

                next unless ($script eq 'postrm');

                # Allow preinst and postinst to remove diversions the
                # package doesn't add to clean up after previous
                # versions of the package.

                $divert = unquote($divert, $expand_diversions);

                $self->tag('remove-of-unknown-diversion', $divert,
                    "$script:$line");
            }
        }
    }

    for my $divert (keys %added_diversions) {
        my $script = $added_diversions{$divert}{'script'};
        my $line = $added_diversions{$divert}{'line'};

        my $divertrx = $divert;
        $divert = unquote($divert, $expand_diversions);

        if (not exists $added_diversions{$divertrx}{'removed'}) {
            $self->tag('orphaned-diversion', $divert, $script);
        }

        # Handle man page diversions somewhat specially.  We may
        # divert away a man page in one section without replacing that
        # same file, since we're installing a man page in a different
        # section.  An example is diverting a man page in section 1
        # and replacing it with one in section 1p (such as
        # libmodule-corelist-perl at the time of this writing).
        #
        # Deal with this by turning all man page diversions into
        # wildcard expressions instead that match everything in the
        # same numeric section so that they'll match the files shipped
        # in the package.
        if ($divertrx =~ m,^(usr\\/share\\/man\\/\S+\\/.*\\\.\d)\w*(\\\.gz\z),)
        {
            $divertrx = "$1.*$2";
            $expand_diversions = 1;
        }

        if ($expand_diversions) {
            $self->tag('diversion-for-unknown-file', $divert, "$script:$line")
              unless (
                any { $_ =~ m/$divertrx/ }
                $processable->installed->sorted_list
              );
        } else {
            $self->tag('diversion-for-unknown-file', $divert, "$script:$line")
              unless $processable->installed->lookup($divert);
        }
    }

    return;
}

# -----------------------------------

# try generic bad maintainer script command tagging
sub generic_check_bad_command {
    my ($self, $line, $file, $lineno, $findincatstring, $in_automatic_section)
      = @_;

    my $pkg = $self->package;

    # try generic bad maintainer script command tagging
  BAD_CMD:
    foreach my $bad_cmd_tag ($BAD_MAINT_CMD->all) {
        my $bad_cmd_data = $BAD_MAINT_CMD->value($bad_cmd_tag);
        my $inscript = $bad_cmd_data->{'in_script'};
        next
          if $in_automatic_section
          and $bad_cmd_data->{'ignore_automatically_added'};
        my $incat;
        if ($file !~ m{$inscript}) {
            next BAD_CMD;
        }
        $incat = $bad_cmd_data->{'in_cat_string'};
        if ($incat == $findincatstring) {
            my $regex = $bad_cmd_data->{'regexp'};
            if ($line =~ m{$regex}) {
                my $extrainfo = defined($1) ? "\'$1\'" : '';
                my $inpackage = $bad_cmd_data->{'in_package'};
                unless($pkg =~ m{$inpackage}) {
                    $self->tag($bad_cmd_tag, "$file:$lineno", $extrainfo);
                }
            }
        }
    }
    return;
}

# Returns non-zero if the given file is not actually a shell script,
# just looks like one.
sub script_is_evil_and_wrong {
    my ($path) = @_;
    my $ret = 0;
    my $i = 0;
    my $var = '0';
    my $backgrounded = 0;
    open(my $fd, '<', $path->unpacked_path);
    local $_;
    while (<$fd>) {
        chomp;
        next if m/^#/;
        next if m/^$/;
        last if (++$i > 55);
        if (
            m~
            # the exec should either be "eval"ed or a new statement
            (?:^\s*|\beval\s*[\'\"]|(?:;|&&|\b(?:then|else))\s*)

            # eat anything between the exec and $0
            exec\s*.+\s*

            # optionally quoted executable name (via $0)
            .?\$$var.?\s*

            # optional "end of options" indicator
            (?:--\s*)?

            # Match expressions of the form '${1+$@}', '${1:+"$@"',
            # '"${1+$@', "$@", etc where the quotes (before the dollar
            # sign(s)) are optional and the second (or only if the $1
            # clause is omitted) parameter may be $@ or $*.
            #
            # Finally the whole subexpression may be omitted for scripts
            # which do not pass on their parameters (i.e. after re-execing
            # they take their parameters (and potentially data) from stdin
            .?(?:\$[{]1:?\+.?)?(?:\$[\@\*])?~x
        ) {
            $ret = 1;
            last;
        } elsif (/^\s*(\w+)=\$0;/) {
            $var = $1;
        } elsif (
            m~
            # Match scripts which use "foo $0 $@ &\nexec true\n"
            # Program name
            \S+\s+

            # As above
            .?\$$var.?\s*
            (?:--\s*)?
            .?(?:\$[{]1:?\+.?)?(?:\$[\@\*])?.?\s*\&~x
        ) {

            $backgrounded = 1;
        } elsif (
            $backgrounded
            and m~
            # the exec should either be "eval"ed or a new statement
            (?:^\s*|\beval\s*[\'\"]|(?:;|&&|\b(?:then|else))\s*)
            exec\s+true(?:\s|\Z)~x
        ) {

            $ret = 1;
            last;
        }
    }
    close($fd);
    return $ret;
}

# Given an interpreter and a file, run the interpreter on that file with the
# -n option to check syntax, discarding output and returning the exit status.
sub check_script_syntax {
    my ($interpreter, $path) = @_;

    safe_qx($interpreter, '-n', $path->unpacked_path);
    return $?;
}

sub remove_comments {
    local $_;

    my $line = shift || '';
    $_ = $line;

    # Remove quoted strings so we can more easily ignore comments
    # inside them
    s/(^|[^\\](?:\\\\)*)\'(?:\\.|[^\\\'])+\'/$1''/g;
    s/(^|[^\\](?:\\\\)*)\"(?:\\.|[^\\\"])+\"/$1""/g;

    # If the remaining string contains what looks like a comment,
    # eat it. In either case, swap the unmodified script line
    # back in for processing (if required) and return it.
    if (m/(?:^|[^[\\])[\s\&;\(\)](\#.*$)/) {
        my $comment = $1;
        $_ = $line;
        s/\Q$comment\E//;  # eat comments
    } else {
        $_ = $line;
    }

    return $_;
}

sub unquote($$) {
    my ($string, $replace_regex) = @_;

    $string =~ s,\\,,g;
    if ($replace_regex) {
        $string =~ s,\.\+,*,g;
    }

    return $string;
}

sub _parse_interpreters {
    my ($interpreter, $value) = @_;
    my ($path, $dep) = split m/\s*,\s*/, $value, 2;
    $dep = $interpreter if not $dep;
    if ($dep eq '@NODEPS@') {
        $dep = '';
    } elsif ($dep =~ m/@/) {
        die "Unknown magic value $dep for versioned interpreter $interpreter";
    }
    return [$path, $dep];
}

sub _parse_versioned_interpreters {
    my ($interpreter, $value) = @_;
    my ($path, $regex, $deptmp, $vers, $deprel) = split m/\s*,\s*/, $value, 5;
    my @versions = split m/\s++/, $vers;
    $deprel = $interpreter if not $deprel;
    if ($deprel eq '@NO_DEFAULT_DEPS@') {
        $deprel = '';
    } elsif ($deprel eq '@SKIP_UNVERSIONED@') {
        $deprel = undef;
    } elsif ($deprel =~ m/@/) {
        die
          "Unknown magic value $deprel for versioned interpreter $interpreter";
    }
    return [$path, $deprel, qr/^$regex$/, $deptmp, \@versions];
}

sub bad_interpreter_tag_name {
    my ($interpreter) = @_;

    return 'incorrect-path-for-interpreter'
      if $interpreter eq '/usr/bin/env perl';

    return 'wrong-path-for-interpreter';
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

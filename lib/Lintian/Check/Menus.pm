# menus -- lintian check script -*- perl -*-

# somewhat of a misnomer -- it doesn't only check menus

# Copyright © 1998 Christian Schwarz
# Copyright © 2018 Chris Lamb <lamby@debian.org>
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

package Lintian::Check::Menus;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Spelling qw(check_spelling check_spelling_picky);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $SLASH => q{/};
const my $DOT => q{.};
const my $QUESTION_MARK => q{?};

# Supported documentation formats for doc-base files.
my %known_doc_base_formats
  = map { $_ => 1 }qw(html text pdf postscript info dvi debiandoc-sgml);

# Known fields for doc-base files.  The value is 1 for required fields and 0
# for optional fields.
my %KNOWN_DOCBASE_MAIN_FIELDS = (
    'Document' => 1,
    'Title'    => 1,
    'Section'  => 1,
    'Abstract' => 0,
    'Author'   => 0
);

my %KNOWN_DOCBASE_FORMAT_FIELDS = (
    'Format'  => 1,
    'Files'   => 1,
    'Index'   => 0
);

has menu_file => (is => 'rw');
has menumethod_file => (is => 'rw');
has documentation => (is => 'rw', default => 0);

sub spelling_tag_emitter {
    my ($self, @orig_args) = @_;
    return sub {
        return $self->hint(@orig_args, @_);
    };
}

sub visit_installed_files {
    my ($self, $file) = @_;

    if ($file->is_file) { # file checks
         # menu file?
        if ($file =~ m{^usr/(lib|share)/menu/\S}) { # correct permissions?

            $self->hint('executable-menu-file',
                sprintf('%s %04o', $file, $file->operm))
              if $file->is_executable;

            return
              if $file =~ m{^usr/(?:lib|share)/menu/README$};

            if ($file =~ m{^usr/lib/}) {
                $self->hint('menu-file-in-usr-lib', $file);
            }

            $self->menu_file($file->name);

            $self->hint('bad-menu-file-name', $file)
              if $file =~ m{^usr/(?:lib|share)/menu/menu$}
              && $self->processable->name ne 'menu';
        }
        #menu-methods file?
        elsif ($file =~ m{^etc/menu-methods/\S}) {
            #TODO: we should test if the menu-methods file
            # is made executable in the postinst as recommended by
            # the menu manual

            my $menumethod_includes_menu_h = 0;
            $self->menumethod_file($file->name);

            if ($file->is_open_ok) {
                open(my $fd, '<', $file->unpacked_path)
                  or die encode_utf8('Cannot open ' . $file->unpacked_path);

                while (my $line = <$fd>) {
                    chomp $line;
                    if ($line =~ /^!include menu.h/) {
                        $menumethod_includes_menu_h = 1;
                        last;
                    }
                }
                close($fd);
            }

            $self->hint('menu-method-lacks-include', $file)
              unless $menumethod_includes_menu_h
              or $self->processable->name eq 'menu';
        }
        # package doc dir?
        elsif (
            $file =~ m{ \A usr/share/doc/(?:[^/]+/)?
                                 (.+\.(?:html|pdf))(?:\.gz)?
                          \Z}xsm
        ) {
            my $name = $1;
            unless ($name =~ m/^changelog\.html$/
                or $name =~ m/^README[.-]/
                or $name =~ m/examples/) {
                $self->documentation(1);
            }
        }
    }

    return;
}

sub installable {
    my ($self) = @_;

    my $pkg = $self->processable->name;
    my $processable = $self->processable;
    my $group = $self->group;

    my (%all_files, %all_links);

    my %preinst;
    my %postinst;
    my %prerm;
    my %postrm;

    $self->check_script(scalar $processable->control->lookup('preinst'),
        \%preinst);
    $self->check_script(scalar $processable->control->lookup('postinst'),
        \%postinst);
    $self->check_script(scalar $processable->control->lookup('prerm'),\%prerm);
    $self->check_script(scalar $processable->control->lookup('postrm'),
        \%postrm);

    # Populate all_{files,links} from current package and its dependencies
    foreach my $bin ($group->get_binary_processables) {
        next
          unless $processable->name eq $bin->name
          or $processable->relation('strong')->satisfies($bin->name);
        for my $file (@{$bin->installed->sorted_list}) {
            add_file_link_info($bin, $file->name, \%all_files,\%all_links);
        }
    }

    # prerm scripts should not call update-menus
    if ($prerm{'calls-updatemenus'}) {
        $self->hint('prerm-calls-updatemenus');
    }

    # postrm scripts should not call install-docs
    if ($postrm{'calls-installdocs'} or $postrm{'calls-installdocs-r'}) {
        $self->hint('postrm-calls-installdocs');
    }

    # preinst scripts should not call either update-menus nor installdocs
    if ($preinst{'calls-updatemenus'}) {
        $self->hint('preinst-calls-updatemenus');
    }

    if ($preinst{'calls-installdocs'}) {
        $self->hint('preinst-calls-installdocs');
    }

    my $anymenu_file = $self->menu_file || $self->menumethod_file;

    # No one needs to call install-docs any more; triggers now handles that.
    if ($postinst{'calls-installdocs'} or $postinst{'calls-installdocs-r'}) {
        $self->hint('postinst-has-useless-call-to-install-docs');
    }
    if ($prerm{'calls-installdocs'} or $prerm{'calls-installdocs-r'}) {
        $self->hint('prerm-has-useless-call-to-install-docs');
    }

    # check consistency
    # docbase file?
    if (my $db_dir
        = $processable->installed->resolve_path('usr/share/doc-base/')){
        for my $dbpath ($db_dir->children) {
            next if not $dbpath->is_open_ok;
            if ($dbpath->resolve_path->is_executable) {
                $self->hint('executable-in-usr-share-docbase',
                    $dbpath,sprintf('%04o', $dbpath->operm));
                next;
            }
            $self->check_doc_base_file($dbpath, \%all_files,\%all_links);
        }
    } elsif ($self->documentation) {
        if ($pkg =~ /^libghc6?-.*-doc$/) {
            # This is the library documentation for a haskell library. Haskell
            # libraries register their documentation via the ghc compiler's
            # documentation registration mechanism.  See bug #586877.
        } else {
            $self->hint('possible-documentation-but-no-doc-base-registration');
        }
    }

    if ($anymenu_file) {
        # postinst and postrm should not need to call update-menus
        # unless there is a menu-method file.  However, update-menus
        # currently won't enable packages that have outstanding
        # triggers, leading to an update-menus call being required for
        # at least some packages right now.  Until this bug is fixed,
        # we still require it.  See #518919 for more information.
        #
        # That bug does not require calling update-menus from postrm,
        # but debhelper apparently currently still adds that to the
        # maintainer script, so don't warn if it's done.
        if (not $postinst{'calls-updatemenus'}) {
            $self->hint('postinst-does-not-call-updatemenus', $anymenu_file);
        }
        if ($self->menumethod_file and not $postrm{'calls-updatemenus'}) {
            $self->hint('postrm-does-not-call-updatemenus',
                $self->menumethod_file)
              unless $pkg eq 'menu';
        }
    } else {
        if ($postinst{'calls-updatemenus'}) {
            $self->hint('postinst-has-useless-call-to-update-menus');
        }
        if ($postrm{'calls-updatemenus'}) {
            $self->hint('postrm-has-useless-call-to-update-menus');
        }
    }

    return;
}

# -----------------------------------

sub check_doc_base_file {
    my ($self, $dbpath, $all_files, $all_links) = @_;

    my $pkg = $self->processable->name;
    my $group = $self->group;

    my $dbfile = $dbpath->basename;

    # another check complains about invalid encoding
    return
      unless ($dbpath->is_valid_utf8);

    my $contents = $dbpath->decoded_utf8;
    my @lines = split(/\n/, $contents);

    my $knownfields = \%KNOWN_DOCBASE_MAIN_FIELDS;
    my ($field, @vals);
    my %sawfields;        # local for each section of control file
    my %sawformats;       # global for control file
    my $line           = 0;  # global

    my $position = 1;
    while (defined(my $string = shift @lines)) {
        chomp $string;

        # New field.  check previous field, if we have any.
        if ($string =~ /^(\S+)\s*:\s*(.*)$/) {
            my (@new) = ($1, $2);
            if ($field) {
                $self->check_doc_base_field(
                    $dbfile, $line, $field,
                    \@vals,\%sawfields, \%sawformats,
                    $knownfields,$all_files, $all_links
                );
            }

            $field = $new[0];

            @vals  = ($new[1]);
            $line  = $position;

            # Continuation of previously defined field.
        } elsif ($field && $string =~ /^\s+\S/) {
            push(@vals, $string);

            # All tags will be reported on the last continuation line of the
            # doc-base field.
            $line  = $position;

            # Sections' separator.
        } elsif ($string =~ /^(\s*)$/) {
            $self->hint('doc-base-file-separator-extra-whitespace',
                "$dbfile:$position")
              if $1;
            next unless $field; # skip successive empty lines

            # Check previously defined field and section.
            $self->check_doc_base_field(
                $dbfile, $line, $field,
                \@vals,\%sawfields, \%sawformats,
                $knownfields,$all_files, $all_links
            );
            $self->check_doc_base_file_section($dbfile, $line + 1,\%sawfields,
                \%sawformats, $knownfields);

            # Initialize variables for new section.
            undef $field;
            undef $line;
            @vals      = ();
            %sawfields = ();

            # Each section except the first one is format section.
            $knownfields = \%KNOWN_DOCBASE_FORMAT_FIELDS;

            # Everything else is a syntax error.
        } else {
            $self->hint('doc-base-file-syntax-error', "$dbfile:$position");
        }

    } continue {
        ++$position;
    }

    # Check the last field/section of the control file.
    if ($field) {
        $self->check_doc_base_field(
            $dbfile, $line, $field,
            \@vals, \%sawfields,\%sawformats,
            $knownfields,$all_files,$all_links
        );
        $self->check_doc_base_file_section($dbfile, $line, \%sawfields,
            \%sawformats,$knownfields);
    }

    # Make sure we saw at least one format.
    $self->hint('doc-base-file-no-format-section', $dbfile)
      unless %sawformats;

    return;
}

# Checks one field of a doc-base control file.  $vals is array ref containing
# all lines of the field.  Modifies $sawfields and $sawformats.
sub check_doc_base_field {
    my (
        $self, $dbfile, $line, $field,$vals,
        $sawfields, $sawformats,$knownfields,$all_files, $all_links
    ) = @_;

    my $pkg = $self->processable->name;
    my $group = $self->group;

    my $SECTIONS = $self->profile->load_data('doc-base/sections');

    $self->hint('doc-base-file-unknown-field', "$dbfile:$line", $field)
      unless defined $knownfields->{$field};
    $self->hint('duplicate-field-in-doc-base', "$dbfile:$line", $field)
      if $sawfields->{$field};
    $sawfields->{$field} = 1;

    # Index/Files field.
    #
    # Check if files referenced by doc-base are included in the package.  The
    # Index field should refer to only one file without wildcards.  The Files
    # field is a whitespace-separated list of files and may contain wildcards.
    # We skip without validating wildcard patterns containing character
    # classes since otherwise we'd need to deal with wildcards inside
    # character classes and aren't there yet.
    if ($field eq 'Index' or $field eq 'Files') {
        my @files = map { split($SPACE, $_) } @{$vals};

        if ($field eq 'Index' && @files > 1) {
            $self->hint('doc-base-index-references-multiple-files',
                "$dbfile:$line");
        }
        for my $file (@files) {
            next if $file =~ m{^/usr/share/doc/};
            next if $file =~ m{^/usr/share/info/};

            $self->hint('doc-base-file-references-wrong-path',
                "$dbfile:$line", $file);
        }
        for my $file (@files) {
            my $realfile = delink($file, $all_links);
            # openoffice.org-dev-doc has thousands of files listed so try to
            # use the hash if possible.
            my $found;
            if ($realfile =~ /[*?]/) {
                my $regex = quotemeta($realfile);
                unless ($field eq 'Index') {
                    next if $regex =~ /\[/;
                    $regex =~ s{\\\*}{[^/]*}g;
                    $regex =~ s{\\\?}{[^/]}g;
                    $regex .= $SLASH . $QUESTION_MARK;
                }
                $found = grep { /^$regex\z/ } keys %{$all_files};
            } else {
                $found = $all_files->{$realfile} || $all_files->{"$realfile/"};
            }
            unless ($found) {
                $self->hint('doc-base-file-references-missing-file',
                    "$dbfile:$line",$file);
            }
        }
        undef @files;

        # Format field.
    } elsif ($field eq 'Format') {
        my $format = join($SPACE, @{$vals});

        # trim both ends
        $format =~ s/^\s+|\s+$//g;

        $format = lc $format;
        $self->hint('doc-base-file-unknown-format', "$dbfile:$line", $format)
          unless $known_doc_base_formats{$format};
        $self->hint('duplicate-format-in-doc-base', "$dbfile:$line", $format)
          if $sawformats->{$format};
        $sawformats->{$format} = 1;

        # Save the current format for the later section check.
        $sawformats->{' *current* '} = $format;

        # Document field.
    } elsif ($field eq 'Document') {
        $_ = join($SPACE, @{$vals});

        $self->hint('doc-base-invalid-document-field', "$dbfile:$line", $_)
          unless /^[a-z0-9+.-]+$/;
        $self->hint('doc-base-document-field-ends-in-whitespace',
            "$dbfile:$line")
          if /[ \t]$/;
        $self->hint('doc-base-document-field-not-in-first-line',
            "$dbfile:$line")
          unless $line == 1;

        # Title field.
    } elsif ($field eq 'Title') {
        if (@{$vals}) {
            my $stag_emitter
              = $self->spelling_tag_emitter(
                'spelling-error-in-doc-base-title-field',
                "${dbfile}:${line}");
            check_spelling(
                $self->profile,
                join($SPACE, @{$vals}),
                $group->spelling_exceptions,
                $stag_emitter
            );
            check_spelling_picky($self->profile, join($SPACE, @{$vals}),
                $stag_emitter);
        }

        # Section field.
    } elsif ($field eq 'Section') {
        $_ = join($SPACE, @{$vals});
        unless ($SECTIONS->recognizes($_)) {
            if (m{^App(?:lication)?s/(.+)$} && $SECTIONS->recognizes($1)) {
                $self->hint('doc-base-uses-applications-section',
                    "$dbfile:$line", $_);
            } elsif (m{^(.+)/(?:[^/]+)$} && $SECTIONS->recognizes($1)) {
                # allows creating a new subsection to a known section
            } else {
                $self->hint('doc-base-unknown-section', "$dbfile:$line", $_);
            }
        }

        # Abstract field.
    } elsif ($field eq 'Abstract') {
        # The three following variables are used for checking if the field is
        # correctly phrased.  We detect if each line (except for the first
        # line and lines containing single dot) of the field starts with the
        # same number of spaces, not followed by the same non-space character,
        # and the number of spaces is > 1.
        #
        # We try to match fields like this:
        #  ||Abstract: The Boost web site provides free peer-reviewed portable
        #  ||  C++ source libraries.  The emphasis is on libraries which work
        #  ||  well with the C++ Standard Library.  One goal is to establish
        #
        # but not like this:
        #  ||Abstract:  This is "Ding"
        #  ||  * a dictionary lookup program for Unix,
        #  ||  * DIctionary Nice Grep,
        my $leadsp;            # string with leading spaces from second line
        my $charafter;         # first non-whitespace char of second line
        my $leadsp_ok = 1;     # are spaces OK?

        # Intentionally skipping the first line.
        for my $idx (1 .. $#{$vals}) {
            $_ = $vals->[$idx];
            if (/manage\s+online\s+manuals\s.*Debian/) {
                $self->hint('doc-base-abstract-field-is-template',
                    "$dbfile:$line")
                  unless $pkg eq 'doc-base';
            } elsif (/^(\s+)\.(\s*)$/ and ($1 ne $SPACE or $2)) {
                $self->hint(
                    'doc-base-abstract-field-separator-extra-whitespace',
                    "$dbfile:" . ($line - $#{$vals} + $idx));
            } elsif (!$leadsp && /^(\s+)(\S)/) {
                # The regexp should always match.
                ($leadsp, $charafter) = ($1, $2);
                $leadsp_ok = $leadsp eq $SPACE;
            } elsif (!$leadsp_ok && /^(\s+)(\S)/) {
                # The regexp should always match.
                undef $charafter if $charafter && $charafter ne $2;
                $leadsp_ok = 1
                  if ($1 ne $leadsp) || ($1 eq $leadsp && $charafter);
            }
        }
        unless ($leadsp_ok) {
            $self->hint(
                'doc-base-abstract-might-contain-extra-leading-whitespace',
                "$dbfile:$line");
        }

        # Check spelling.
        if (@{$vals}) {
            my $stag_emitter
              = $self->spelling_tag_emitter(
                'spelling-error-in-doc-base-abstract-field',
                "${dbfile}:${line}");
            check_spelling(
                $self->profile,
                join($SPACE, @{$vals}),
                $group->spelling_exceptions,
                $stag_emitter
            );
            check_spelling_picky($self->profile, join($SPACE, @{$vals}),
                $stag_emitter);
        }
    }

    return;
}

# Checks the section of the doc-base control file.  Tries to find required
# fields missing in the section.
sub check_doc_base_file_section {
    my ($self, $dbfile, $line, $sawfields, $sawformats, $knownfields) = @_;

    $self->hint('doc-base-file-no-format', "$dbfile:$line")
      if ((defined $sawfields->{'Files'} || defined $sawfields->{'Index'})
        && !(defined $sawfields->{'Format'}));

    # The current format is set by check_doc_base_field.
    if ($sawfields->{'Format'}) {
        my $format =  $sawformats->{' *current* '};
        $self->hint('doc-base-file-no-index', "$dbfile:$line")
          if ( $format
            && ($format eq 'html' || $format eq 'info')
            && !$sawfields->{'Index'});
    }
    for my $field (sort keys %{$knownfields}) {
        $self->hint('doc-base-file-lacks-required-field',
            "$dbfile:$line", $field)
          if ($knownfields->{$field} == 1 && !$sawfields->{$field});
    }

    return;
}

# Add file and link to $all_files and $all_links.  Note that both files and
# links have to include a leading /.
sub add_file_link_info {
    my ($processable, $file, $all_files, $all_links) = @_;
    my $link = $processable->installed->lookup($file)->link;
    my $ishard = $processable->installed->lookup($file)->is_hardlink;

    # make name absolute
    $file = $SLASH . $file
      unless $file =~ m{^/};

    $file =~ s{/+}{/}g;                           # remove duplicated `/'
    $all_files->{$file} = 1;

    if (length $link) {

        $link = $DOT . $SLASH . $link
          if $link !~ m{^/};

        if ($ishard) {
            $link =~ s{^\./}{/};
        } elsif ($link !~ m{^/}) {            # not absolute link
            $link
              = $SLASH
              . $link;                  # make sure link starts with '/'
            $link =~ s{/+\./+}{/}g;                # remove all /./ parts
            my $dcount = 1;
            while ($link =~ s{^/+\.\./+}{/}) {     #\ count & remove
                $dcount++;                         #/ any leading /../ parts
            }
            my $f = $file;
            while ($dcount--) {                   #\ remove last $dcount
                $f=~ s{/[^/]*$}{};                #/ path components from $file
            }
            $link
              = $f. $link;                   # now we should have absolute link
        }
        $all_links->{$file} = $link unless ($link eq $file);
    }

    return;
}

# Dereference all symlinks in file.
sub delink {
    my ($file, $all_links) = @_;

    $file =~ s{/+}{/}g;                            # remove duplicated '/'
    return $file
      unless %{$all_links};              # package doesn't symlinks

    my $p1 = $EMPTY;
    my $p2 = $file;
    my %used_links;

    # In the loop below we split $file into two parts on each '/' until
    # there's no remaining slashes.  We try substituting the first part with
    # corresponding symlink and if it succeeds, we start the procedure from
    # beginning.
    #
    # Example:
    #    Let $all_links{"/a/b"} == "/d", and $file == "/a/b/c"
    #    Then 0) $p1 == "",     $p2 == "/a/b/c"
    #         1) $p1 == "/a",   $p2 == "/b/c"
    #         2) $p1 == "/a/b", $p2 == "/c"      ; substitute "/d" for "/a/b"
    #         3) $p1 == "",     $p2 == "/d/c"
    #         4) $p1 == "/d",   $p2 == "/c"
    #         5) $p1 == "/d/c", $p2 == ""
    #
    # Note that the algorithm supposes, that
    #    i) $all_links{$X} != $X for each $X
    #   ii) both keys and values of %all_links start with '/'

    while (($p2 =~ s{^(/[^/]*)}{}g) > 0) {
        $p1 .= $1;
        if (defined $all_links->{$p1}) {
            return '!!! SYMLINK LOOP !!!' if defined $used_links{$p1};
            $p2 = $all_links->{$p1} . $p2;
            $p1 = $EMPTY;
            $used_links{$p1} = 1;
        }
    }

    # After the loop $p2 should be empty and $p1 should contain the target
    # file.  In some rare cases when $file contains no slashes, $p1 will be
    # empty and $p2 will contain the result (which will be equal to $file).
    return $p1 ne $EMPTY ? $p1 : $p2;
}

sub check_script {
    my ($self, $spath, $pres) = @_;

    my $pkg = $self->processable->name;

    my ($no_check_menu, $no_check_installdocs);

    # control files are regular files and not symlinks, pipes etc.
    return if not $spath or $spath->is_symlink or not $spath->is_open_ok;

    # nothing to do for ELF
    return
      if $spath->is_elf;

    open(my $fd, '<', $spath->unpacked_path)
      or die encode_utf8('Cannot open ' . $spath->unpacked_path);

    # discard hashbang line; will get from Index::Item
    scalar readline $fd;

    my $interp = $spath->interpreter || 'unknown';

    if ($spath->is_shell_script) {
        $interp = 'sh';

    } elsif ($interp =~ m{^/usr/bin/perl}) {
        $interp = 'perl';
    }

    while (my $line = <$fd>) {
        # skip comments
        $line =~ s/\#.*$//;

        ##
        # update-menus will satisfy the checks that the menu file
        # installed is properly used
        ##

        # does the script check whether update-menus exists?
        $pres->{'checks-for-updatemenus'} = 1
          if $line =~ /-x\s+\S*update-menus/
          || $line =~ /(?:which|type)\s+update-menus/
          || $line =~ /command\s+.*?update-menus/;

        # does the script call update-menus?
        # TODO this regex-magic should be moved to some lib for checking
        # whether a certain word is likely called as command... --Jeroen
        if (
            $line =~m{ (?:^\s*|[;&|]\s*|(?:then|do|exec)\s+)
               (?:\/usr\/bin\/)?update-menus
               (?:\s|[;&|<>]|\Z)}xsm
        ) {
            # yes, it does.
            $pres->{'calls-updatemenus'} = 1;

            # checked first?
            if (not $pres->{'checks-for-updatemenus'} and $pkg ne 'menu') {
                $self->hint(
'maintainer-script-does-not-check-for-existence-of-updatemenus',
                    "$spath:$."
                ) unless $no_check_menu++;
            }
        }

        # does the script check whether install-docs exists?
        $pres->{'checks-for-installdocs'} = 1
          if $line =~ s/-x\s+\S*install-docs//
          || $line =~/(?:which|type)\s+install-docs/
          || $line =~ s/command\s+.*?install-docs//;

        # does the script call install-docs?
        if (
            $line =~ m{ (?:^\s*|[;&|]\s*|(?:then|do)\s+)
               (?:\/usr\/sbin\/)?install-docs
               (?:\s|[;&|<>]|\Z) }xsm
        ) {
            # yes, it does.  Does it remove or add a doc?
            if ($line =~ /install-docs\s+(?:-r|--remove)\s/) {
                $pres->{'calls-installdocs-r'} = 1;
            } else {
                $pres->{'calls-installdocs'} = 1;
            }

            # checked first?
            if (not $pres->{'checks-for-installdocs'}) {
                $self->hint(
'maintainer-script-does-not-check-for-existence-of-installdocs',
                    $spath
                ) unless $no_check_installdocs++;
            }
        }
    }

    close($fd);

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

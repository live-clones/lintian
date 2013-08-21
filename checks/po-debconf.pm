# po-debconf -- lintian check script -*- perl -*-

# Copyright (C) 2002-2004 by Denis Barbier <barbier@linuxfr.org>
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

package Lintian::po_debconf;
use strict;
use warnings;
use autodie;

use Lintian::Tags qw(tag);
use Lintian::Util qw(is_ancestor_of system_env);

sub run {
    my (undef, undef, $info) = @_;
    my $full_translation = 0;
    my $debfiles = $info->debfiles;

    # First, check wether this package seems to use debconf but not
    # po-debconf.  Read the templates file and look at the template
    # names it provides, since some shared templates aren't
    # translated.
    opendir(my $dirfd, $debfiles);

    my $has_template = my $has_depends = my $has_config = 0;
    my @lang_templates;
    for my $file (readdir($dirfd)) {
        next if -d "$debfiles/$file";
        if ($file =~ m/^(.+\.)?templates(\..+)?$/) {
            if ($file =~ m/templates\.\w\w(_\w\w)?$/) {
                push(@lang_templates, $file);
                open(my $fd, '<', "$debfiles/$file");
                while (<$fd>) {
                    tag 'untranslatable-debconf-templates', "$file: $."
                      if (m/^Description: (.+)/i and $1 !~/for internal use/);
                }
                close($fd);
            } else {
                open(my $fd, '<', "$debfiles/$file");
                my $in_template = 0;
                my $saw_tl_note = 0;
                while (<$fd>) {
                    tag 'translated-default-field', "$file: $."
                      if (m{^_Default(?:Choice)?: [^\[]*$}) && !$saw_tl_note;
                    tag 'untranslatable-debconf-templates', "$file: $."
                      if (m/^Description: (.+)/i and $1 !~/for internal use/);

                    if (/^#/) {
                        # Is this a comment for the translators?
                        $saw_tl_note = 1 if m/translators/i;
                        next;
                    }

                    # If it is not a continuous comment immediately before the
                    # _Default(Choice) field, we don't care about it.
                    $saw_tl_note = 0;

                    if (/^Template: (\S+)/i) {
                        my $template = $1;
                        next
                          if $template eq 'shared/packages-wordlist'
                          or $template eq 'shared/packages-ispell';
                        next if $template =~ m,/languages$,;
                        $in_template = 1;
                    } elsif ($in_template and /^_?Description: (.+)/i) {
                        my $description = $1;
                        next if $description =~ /for internal use/;
                        $has_template = 1;
                    } elsif ($in_template and /^$/) {
                        $in_template = 0;
                    }
                }
                close($fd);
            }
        }
    }
    closedir($dirfd);

    #TODO: check whether all templates are named in TEMPLATES.pot
    if ($has_template) {
        if (-l "$debfiles/po"
            and not is_ancestor_of($debfiles, "$debfiles/po")) {
            # debian/po is an unsafe symlink - lets stop here.
            return;
        }
        if (!-d "$debfiles/po") {
            tag 'not-using-po-debconf';
            return;
        }
    } else {
        return;
    }

    # If we got here, we're using po-debconf, so there shouldn't be any stray
    # language templates left over from debconf-mergetemplate.
    for (@lang_templates) {
        tag 'stray-translated-debconf-templates', $_ unless /templates\.in$/;
    }

    my $missing_files = 0;

    if (-f "$debfiles/po/POTFILES.in" and not -l "$debfiles/po/POTFILES.in") {
        open(my $fd, '<', "$debfiles/po/POTFILES.in");
        while (<$fd>) {
            chomp;
            next if /^\s*\#/;
            s/.*\]\s*//;
            #  Cannot check files which are not under debian/
            next if m,^\.\./, or $_ eq '';
            unless (-f "$debfiles/$_") {
                tag 'missing-file-from-potfiles-in', $_;
                $missing_files = 1;
            }
        }
        close($fd);
    } else {
        tag 'missing-potfiles-in';
        $missing_files = 1;
    }
    if (!-f "$debfiles/po/templates.pot" && !-l "$debfiles/po/templates.pot") {
        tag 'missing-templates-pot';
        $missing_files = 1;
    }

    if ($missing_files == 0) {
#<<< No tidy - though we should rewrite this to avoid writing during checks (#699022)
        $ENV{'INTLTOOL_EXTRACT'} = '/usr/share/intltool-debian/intltool-extract';
        system_env("cd \Q$debfiles/po\E && /usr/share/intltool-debian/intltool-update --gettext-package=test --pot");
        system_env("/usr/bin/msgcmp --use-untranslated \Q$debfiles/po/test.pot\E \Q$debfiles/po/templates.pot\E >/dev/null 2>&1"
              . "&& /usr/bin/msgcmp --use-untranslated \Q$debfiles/po/templates.pot\E \Q$debfiles/po/test.pot\E >/dev/null 2>&1"
          ) == 0 or tag 'newer-debconf-templates';
#>>>
    }

    opendir(my $po_dirfd, "$debfiles/po");
    while (defined(my $file=readdir($po_dirfd))) {
        next unless $file =~ m/\.po$/;
        tag 'misnamed-po-file', "debian/po/$file"
          unless ($file =~ /^[a-z]{2,3}(_[A-Z]{2})?(?:\@[^\.]+)?\.po$/o);
        local ($/) = "\n\n";
        $_ = '';
        # skip suspicious "files"
        next if -l "$debfiles/po/$file" || !-f "$debfiles/po/$file";
        open(my $fd, '<', "$debfiles/po/$file");
        while (<$fd>) {
            if (/Language\-Team:.*debian-i18n\@lists\.debian\.org/i) {
                tag 'debconf-translation-using-general-list', $file;
            }
            last if m/^msgstr/m;
        }
        close($fd);
        unless ($_) {
            tag 'invalid-po-file', "debian/po/$file";
            next;
        }
        s/"\n"//g;
        my $charset = '';
        if (m/charset=(.*?)\\n/) {
            $charset = ($1 eq 'CHARSET' ? '' : $1);
        }
        tag 'unknown-encoding-in-po-file', "debian/po/$file"
          unless length($charset);
        system_env(
            'msgfmt -o /dev/null'. " \Q$debfiles/po/$file\E 2>/dev/null") == 0
          or tag 'invalid-po-file', "debian/po/$file";

        my $stats
          = `LC_ALL=C msgfmt -o /dev/null --statistics \Q$debfiles/po/$file\E 2>&1`;
        if (!$full_translation && $stats =~ m/^\w+ \w+ \w+\.$/) {
            $full_translation = 1;
        }
    }
    closedir($po_dirfd);

    tag 'no-complete-debconf-translation' if !$full_translation;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

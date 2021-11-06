# debian/po-debconf -- lintian check script -*- perl -*-

# Copyright © 2002-2004 by Denis Barbier <barbier@linuxfr.org>
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

package Lintian::Check::Debian::PoDebconf;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Cwd qw(realpath);
use File::Temp();
use IPC::Run3;
use Syntax::Keyword::Try;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::IPC::Run3 qw(safe_qx);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

sub source {
    my ($self) = @_;

    my $processable = $self->processable;

    my $has_template = 0;
    my @lang_templates;
    my $full_translation = 0;
    my $debian_dir = $processable->patched->resolve_path('debian/');
    return if not $debian_dir;
    my $debian_po_dir = $debian_dir->resolve_path('po');
    my ($templ_pot_path, $potfiles_in_path);

    if ($debian_po_dir and $debian_po_dir->is_dir) {
        $templ_pot_path = $debian_po_dir->resolve_path('templates.pot');
        $potfiles_in_path = $debian_po_dir->resolve_path('POTFILES.in');
    }

    # First, check whether this package seems to use debconf but not
    # po-debconf.  Read the templates file and look at the template
    # names it provides, since some shared templates aren't
    # translated.
    for my $path ($debian_dir->children) {
        next if not $path->is_open_ok;
        my $basename = $path->basename;
        if ($basename =~ m/^(.+\.)?templates(\..+)?$/) {
            if ($basename =~ m/templates\.\w\w(_\w\w)?$/) {
                push(@lang_templates, $basename);

                open(my $fd, '<', $path->unpacked_path)
                  or die encode_utf8('Cannot open ' . $path->unpacked_path);

                while (my $line = <$fd>) {

                    $self->hint('untranslatable-debconf-templates',
                        "$basename: $.")
                      if $line =~ /^Description: (.+)/i
                      && $1 !~/for internal use/;
                }
                close($fd);

            } else {
                open(my $fd, '<', $path->unpacked_path)
                  or die encode_utf8('Cannot open ' . $path->unpacked_path);

                my $in_template = 0;
                my $saw_tl_note = 0;
                while (my $line = <$fd>) {
                    chomp $line;

                    $self->hint('translated-default-field', "$basename: $.")
                      if $line =~ m{^_Default(?:Choice)?: [^\[]*$}
                      && !$saw_tl_note;

                    $self->hint('untranslatable-debconf-templates',
                        "$basename: $.")
                      if $line =~ /^Description: (.+)/i
                      && $1 !~/for internal use/;

                    if ($line =~ /^#/) {
                        # Is this a comment for the translators?
                        $saw_tl_note = 1
                          if $line =~ /translators/i;

                        next;
                    }

                    # If it is not a continuous comment immediately before the
                    # _Default(Choice) field, we don't care about it.
                    $saw_tl_note = 0;

                    if ($line =~ /^Template: (\S+)/i) {
                        my $template = $1;
                        next
                          if $template eq 'shared/packages-wordlist'
                          or $template eq 'shared/packages-ispell';

                        next
                          if $template =~ m{/languages$};

                        $in_template = 1;

                    } elsif ($in_template && $line =~ /^_?Description: (.+)/i){
                        my $description = $1;
                        next
                          if $description =~ /for internal use/;
                        $has_template = 1;

                    } elsif ($in_template && !length($line)) {
                        $in_template = 0;
                    }
                }

                close($fd);
            }
        }
    }

    #TODO: check whether all templates are named in TEMPLATES.pot
    if ($has_template) {
        if (not $debian_po_dir or not $debian_po_dir->is_dir) {
            $self->hint('not-using-po-debconf');
            return;
        }
    } else {
        return;
    }

    # If we got here, we're using po-debconf, so there shouldn't be any stray
    # language templates left over from debconf-mergetemplate.
    for (@lang_templates) {
        $self->hint('stray-translated-debconf-templates', $_)
          unless /templates\.in$/;
    }

    my $missing_files = 0;

    if ($potfiles_in_path and $potfiles_in_path->is_open_ok) {

        open(my $fd, '<', $potfiles_in_path->unpacked_path)
          or
          die encode_utf8('Cannot open ' . $potfiles_in_path->unpacked_path);

        while (my $line = <$fd>) {
            chomp $line;

            next
              if $line =~ /^\s*\#/;

            $line =~ s/.*\]\s*//;

            #  Cannot check files which are not under debian/
            next
              if $line eq $EMPTY; #m,^\.\./, or

            my $po_path = $debian_dir->resolve_path($line);
            unless ($po_path and $po_path->is_file) {
                $self->hint('missing-file-from-potfiles-in', $line);
                $missing_files = 1;
            }
        }
        close($fd);

    } else {
        $self->hint('missing-potfiles-in');
        $missing_files = 1;
    }
    if (not $templ_pot_path or not $templ_pot_path->is_open_ok) {
        # We use is_open_ok here, because if it is present, we will
        # (have a subprocess) open it if the POTFILES.in file also
        # existed.
        $self->hint('missing-templates-pot');
        $missing_files = 1;
    }

    if ($missing_files == 0) {
        my $temp_obj
          = File::Temp->newdir('lintian-po-debconf-XXXXXX',TMPDIR => 1);
        my $abs_tempdir = realpath($temp_obj->dirname)
          or croak('Cannot resolve ' . $temp_obj->dirname . ": $!");
        # We need an extra level of dirs, as intltool (in)directly
        # tries to use files in ".." if they exist
        # (e.g. ../templates.h).
        # - In fact, we also need to copy debian/templates into
        #   this "fake package directory", since intltool-updates
        #   sometimes want to write files to "../templates" based
        #   on the contents of the package.  (See #778558)
        my $tempdir = "$abs_tempdir/po";
        my $test_pot = "$tempdir/test.pot";
        my $tempdir_templates = "${abs_tempdir}/templates";
        my $d_templates = $debian_dir->resolve_path('templates');

        # Create our extra level
        mkdir($tempdir)
          or die encode_utf8('Cannot create directory ' . $tempdir);

        # Copy the templates dir because intltool-update might
        # write to it.
        safe_qx(
            qw{cp -a --reflink=auto --},
            $d_templates->unpacked_path,
            $tempdir_templates
        )if $d_templates;

        my $error;
        my %save = %ENV;
        my $cwd = Cwd::getcwd;

        try {
            $ENV{INTLTOOL_EXTRACT}
              = '/usr/share/intltool-debian/intltool-extract';
            # use of $debian_po is safe; we accessed two children by now.
            $ENV{srcdir} = $debian_po_dir->unpacked_path;

            chdir($tempdir)
              or die encode_utf8('Cannot change directory ' . $tempdir);

            # generate a "test.pot" in a tempdir
            my @intltool = (
                '/usr/share/intltool-debian/intltool-update',
                '--gettext-package=test','--pot'
            );
            safe_qx(@intltool);
            die encode_utf8("system @intltool failed: $?")
              if $?;

        } catch {
            # catch any error
            $error = $@;

        } finally {
            # restore environment
            %ENV = %save;

            # restore working directory
            chdir($cwd)
              or die encode_utf8('Cannot change directory ' . $cwd);
        }

        # output could be helpful to user but is currently not printed

        if ($error) {
            $self->hint('invalid-potfiles-in');
            return;
        }

        # throw away output on the following commands
        $error = undef;

        try {
            # compare our "test.pot" with the existing "templates.pot"
            my @testleft = (
                'msgcmp', '--use-untranslated',
                $test_pot, $templ_pot_path->unpacked_path
            );
            safe_qx(@testleft);
            die encode_utf8("system @testleft failed: $?")
              if $?;

            # is this not equivalent to the previous command? - FL
            my @testright = (
                'msgcmp', '--use-untranslated',
                $templ_pot_path->unpacked_path, $test_pot
            );
            safe_qx(@testright);
            die encode_utf8("system @testright failed: $?")
              if $?;

        } catch {
            # catch any error
            $error = $@;
        }

        $self->hint('newer-debconf-templates') if length $error;
    }

    return unless $debian_po_dir;

    for my $po_path ($debian_po_dir->children) {
        my $basename = $po_path->basename;
        next unless $basename =~ m/\.po$/ || $po_path->is_dir;
        $self->hint('misnamed-po-file', $po_path)
          unless ($basename =~ /^[a-z]{2,3}(_[A-Z]{2})?(?:\@[^\.]+)?\.po$/);
        next
          unless $po_path->is_open_ok;

        my $bytes = $po_path->bytes;

        $self->hint('debconf-translation-using-general-list', $basename)
          if $bytes =~ /Language\-Team:.*debian-i18n\@lists\.debian\.org/i;

        unless ($bytes =~ /^msgstr/m) {

            $self->hint('invalid-po-file', $po_path);
            next;
        }

        if ($bytes =~ /charset=(.*?)\\n/) {

            my $charset = ($1 eq 'CHARSET' ? $EMPTY : $1);

            $self->hint('unknown-encoding-in-po-file', $po_path)
              unless length $charset;
        }

        my $error;

        my $stats;

        delete local $ENV{$_}
          for grep { $_ ne 'PATH' && $_ ne 'TMPDIR' } keys %ENV;
        local $ENV{LC_ALL} = 'C';

        my @command = ('msgfmt', '-o', '/dev/null', '--statistics',
            $po_path->unpacked_path);

        run3(\@command, \undef, \undef, \$stats);

        $self->hint('invalid-po-file', $po_path)
          if $?;

        $stats //= $EMPTY;

        $full_translation = 1
          if $stats =~ m/^\w+ \w+ \w+\.$/;
    }

    $self->hint('no-complete-debconf-translation') if !$full_translation;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

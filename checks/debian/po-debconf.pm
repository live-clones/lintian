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

package Lintian::debian::po_debconf;

use v5.20;
use warnings;
use utf8;
use autodie;

use Capture::Tiny qw(capture_merged capture_stderr);
use Cwd qw(realpath);
use File::Temp();
use Try::Tiny;

use Lintian::Util qw(copy_dir clean_env);

use constant NEWLINE  =>  qq{\n};

use Moo;
use namespace::clean;

with 'Lintian::Check';

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
                open(my $fd, '<', $path->unpacked_path);
                while (<$fd>) {
                    $self->tag('untranslatable-debconf-templates',
                        "$basename: $.")
                      if (m/^Description: (.+)/i and $1 !~/for internal use/);
                }
                close($fd);
            } else {
                open(my $fd, '<', $path->unpacked_path);
                my $in_template = 0;
                my $saw_tl_note = 0;
                while (<$fd>) {
                    $self->tag('translated-default-field', "$basename: $.")
                      if (m{^_Default(?:Choice)?: [^\[]*$}) && !$saw_tl_note;
                    $self->tag('untranslatable-debconf-templates',
                        "$basename: $.")
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

    #TODO: check whether all templates are named in TEMPLATES.pot
    if ($has_template) {
        if (not $debian_po_dir or not $debian_po_dir->is_dir) {
            $self->tag('not-using-po-debconf');
            return;
        }
    } else {
        return;
    }

    # If we got here, we're using po-debconf, so there shouldn't be any stray
    # language templates left over from debconf-mergetemplate.
    for (@lang_templates) {
        $self->tag('stray-translated-debconf-templates', $_)
          unless /templates\.in$/;
    }

    my $missing_files = 0;

    if ($potfiles_in_path and $potfiles_in_path->is_open_ok) {
        open(my $fd, '<', $potfiles_in_path->unpacked_path);
        while (<$fd>) {
            chomp;
            next if /^\s*\#/;
            s/.*\]\s*//;
            #  Cannot check files which are not under debian/
            next if $_ eq ''; #m,^\.\./, or
            my $po_path = $debian_dir->resolve_path($_);
            unless ($po_path and $po_path->is_file) {
                $self->tag('missing-file-from-potfiles-in', $_);
                $missing_files = 1;
            }
        }
        close($fd);
    } else {
        $self->tag('missing-potfiles-in');
        $missing_files = 1;
    }
    if (not $templ_pot_path or not $templ_pot_path->is_open_ok) {
        # We use is_open_ok here, because if it is present, we will
        # (have a subprocess) open it if the POTFILES.in file also
        # existed.
        $self->tag('missing-templates-pot');
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
        mkdir($tempdir);
        # Copy the templates dir because intltool-update might
        # write to it.
        copy_dir($d_templates->unpacked_path, $tempdir_templates)
          if $d_templates;

        my $error;
        my %save = %ENV;
        my $cwd = Cwd::getcwd;
        my $output = capture_merged {
            try {
                $ENV{INTLTOOL_EXTRACT}
                  = '/usr/share/intltool-debian/intltool-extract';
                # use of $debian_po is safe; we accessed two children by now.
                $ENV{srcdir} = $debian_po_dir->unpacked_path;

                chdir($tempdir);

                # generate a "test.pot" in a tempdir
                my @intltool = (
                    '/usr/share/intltool-debian/intltool-update',
                    '--gettext-package=test','--pot'
                );
                system(@intltool) == 0
                  or die "system @intltool failed: $?";
            }catch {
                # catch any error
                $error = $_;
            }finally {
                # restore environment
                %ENV = %save;

                # restore working directory
                chdir($cwd);
            };
        };

        # output could be helpful to user but is currently not printed

        if ($error) {
            $self->tag('invalid-potfiles-in');
            return;
        }

        # throw away output on the following commands
        $error = undef;
        $output = capture_merged {
            try {
                # compare our "test.pot" with the existing "templates.pot"
                my @testleft = (
                    'msgcmp', '--use-untranslated',
                    $test_pot, $templ_pot_path->unpacked_path
                );
                system(@testleft) == 0
                  or die "system @testleft failed: $?";

                # is this not equivalent to the previous command? - FL
                my @testright = (
                    'msgcmp', '--use-untranslated',
                    $templ_pot_path->unpacked_path, $test_pot
                );
                system(@testright) == 0
                  or die "system @testright failed: $?";
            }catch {
                # catch any error
                $error = $_;
            };
        };

        $self->tag('newer-debconf-templates') if length $error;
    }

    return unless $debian_po_dir;

    for my $po_path ($debian_po_dir->children) {
        my $basename = $po_path->basename;
        next unless $basename =~ m/\.po$/ || $po_path->is_dir;
        $self->tag('misnamed-po-file', $po_path)
          unless ($basename =~ /^[a-z]{2,3}(_[A-Z]{2})?(?:\@[^\.]+)?\.po$/);
        next unless $po_path->is_open_ok;
        local ($/) = "\n\n";
        $_ = '';
        open(my $fd, '<', $po_path->unpacked_path);
        while (<$fd>) {

            if (/Language\-Team:.*debian-i18n\@lists\.debian\.org/i) {
                $self->tag('debconf-translation-using-general-list',$basename);
            }
            last if m/^msgstr/m;
        }
        close($fd);
        unless ($_) {
            $self->tag('invalid-po-file', $po_path);
            next;
        }
        s/"\n"//g;
        my $charset = '';
        if (m/charset=(.*?)\\n/) {
            $charset = ($1 eq 'CHARSET' ? '' : $1);
        }
        $self->tag('unknown-encoding-in-po-file', $po_path)
          unless length($charset);

        my $error;
        my %save = %ENV;
        my $stats = capture_stderr {
            try {
                clean_env(1);
                my @msgfmt = (
                    'msgfmt', '-o', '/dev/null', '--statistics',
                    $po_path->unpacked_path
                );
                system(@msgfmt) == 0
                  or die "system @msgfmt failed: $?";
            }catch {
                # catch any error
                $error = $_;
            }finally {
                # restore environment
                %ENV = %save;
            };
        };

        $self->tag('invalid-po-file', $po_path) if length $error;

        if (!$full_translation && $stats =~ m/^\w+ \w+ \w+\.$/) {
            $full_translation = 1;
        }
    }

    $self->tag('no-complete-debconf-translation') if !$full_translation;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

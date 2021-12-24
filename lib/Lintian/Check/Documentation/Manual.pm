# documentation/manual -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz
# Copyright © 2019-2020 Felix Lechner
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

package Lintian::Check::Documentation::Manual;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Cwd qw(getcwd);
use File::Basename;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use IPC::Run3;
use List::Compare;
use List::SomeUtils qw(any none);
use Path::Tiny;
use Text::Balanced qw(extract_delimited);
use Unicode::UTF8 qw(valid_utf8 decode_utf8 encode_utf8);

use Lintian::Spelling qw(check_spelling);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $COLON => q{:};
const my $COMMA => q{,};
const my $DOT => q{.};
const my $NEWLINE => qq{\n};

const my $USER_COMMAND_SECTION => 1;
const my $SYSTEM_COMMAND_SECTION => 8;

const my $WAIT_STATUS_SHIFT => 8;
const my $MINIMUM_SHARED_OBJECT_SIZE => 256;
const my $WIDE_SCREEN => 120;

has local_manpages => (is => 'rw', default => sub { {} });

sub spelling_tag_emitter {
    my ($self, $tag_name, $pointer, @orig_args) = @_;

    return sub {
        return $self->pointed_hint($tag_name, $pointer, @orig_args, @_);
    };
}

my @user_locations= qw(bin/ usr/bin/ usr/bin/X11/ usr/bin/mh/ usr/games/);
my @admin_locations= qw(sbin/ usr/sbin/);

sub visit_installed_files {
    my ($self, $item) = @_;

    # no man pages in udebs
    return
      if $self->processable->type eq 'udeb';

    if ($item->name =~ m{^usr/share/man/\S+}) {

        $self->pointed_hint('manual-page-in-udeb', $item->pointer)
          if $self->processable->type eq 'udeb';

        if ($item->is_dir) {
            $self->pointed_hint('stray-folder-in-manual', $item->pointer)
              unless $item->name
              =~ m{^usr/(?:X11R6|share)/man/(?:[^/]+/)?(?:man\d/)?$};

        } elsif ($item->is_file && $item->is_executable) {
            $self->pointed_hint('executable-manual-page', $item->pointer);
        }
    }

    return
      unless $item->is_file || $item->is_symlink;

    my ($manpage, $page_path, undef) = fileparse($item);

    if ($page_path eq 'usr/share/man/' && $manpage ne $EMPTY) {
        $self->pointed_hint('odd-place-for-manual-page', $item->pointer);
        return;
    }

    # manual page?
    my ($subdir) = ($page_path =~ m{^usr/share/man(/\S+)});
    return
      unless defined $subdir;

    $self->pointed_hint('build-path-in-manual', $item->pointer)
      if $item =~ m{/_build_} || $item =~ m{_tmp_buildd};

    $self->pointed_hint('manual-page-with-generic-name', $item->pointer)
      if $item =~ m{/README\.};

    my ($section) = ($subdir =~ m{^.*man(\d)/$});
    unless (defined $section) {
        $self->pointed_hint('odd-place-for-manual-page', $item->pointer);
        return;
    }

    my ($language) = ($subdir =~ m{^/([^/]+)/man\d/$});
    $language //= $EMPTY;

    # The country should not be part of the man page locale
    # directory unless it's one of the known cases where the
    # language is significantly different between countries.
    $self->pointed_hint('country-in-manual', $item->pointer)
      if $language =~ /_/ && $language !~ /^(?:pt_BR|zh_[A-Z][A-Z])$/;

    my @pieces = split(/\./, $manpage);
    my $ext = pop @pieces;

    if ($ext ne 'gz') {

        push @pieces, $ext;
        $self->pointed_hint('uncompressed-manual-page', $item->pointer);

    } elsif ($item->is_file) { # so it's .gz... files first; links later

        if ($item->file_type !~ m/gzip compressed data/) {
            $self->pointed_hint('wrong-compression-in-manual-page',
                $item->pointer);

        } elsif ($item->file_type !~ m/max compression/) {
            $self->pointed_hint('poor-compression-in-manual-page',
                $item->pointer);
        }
    }

    my $fn_section = pop @pieces;
    my $section_num = $fn_section;

    if (scalar @pieces && $section_num =~ s/^(\d).*$/$1/) {

        my $bin = join($DOT, @pieces);
        $self->local_manpages->{$bin} = []
          unless $self->local_manpages->{$bin};

        push @{$self->local_manpages->{$bin}},
          { file => $item, language => $language, section => $section };

        # number of directory and manpage extension equal?
        if ($section_num != $section) {
            $self->pointed_hint('odd-place-for-manual-page', $item->pointer);
        }

    } else {
        $self->pointed_hint('wrong-name-for-manual-page', $item->pointer);
    }

    # check symbolic links to other manual pages
    if ($item->is_symlink) {
        if ($item->link =~ m{(^|/)undocumented}) {
            # undocumented link in /usr/share/man -- possibilities
            #    undocumented... (if in the appropriate section)
            #    ../man?/undocumented...
            #    ../../man/man?/undocumented...
            #    ../../../share/man/man?/undocumented...
            #    ../../../../usr/share/man/man?/undocumented...
            if ((
                       $item->link =~ m{^undocumented\.([237])\.gz}
                    && $page_path =~ m{^usr/share/man/man$1}
                )
                || $item->link =~ m{^\.\./man[237]/undocumented\.[237]\.gz$}
                || $item->link
                =~ m{^\.\./\.\./man/man[237]/undocumented\.[237]\.gz$}
                || $item->link
                =~ m{^\.\./\.\./\.\./share/man/man[237]/undocumented\.[237]\.gz$}
                || $item->link
                =~ m{^\.\./\.\./\.\./\.\./usr/share/man/man[237]/undocumented\.[237]\.gz$}
            ) {
                $self->pointed_hint('undocumented-manual-page',$item->pointer);
            } else {
                $self->pointed_hint('broken-link-to-undocumented',
                    $item->pointer);
            }
        }
    } else { # not a symlink

        my $fd;
        if ($item->file_type =~ m/gzip compressed/) {

            open($fd, '<:gzip', $item->unpacked_path)
              or die encode_utf8('Cannot open ' . $item->unpacked_path);

        } else {

            open($fd, '<', $item->unpacked_path)
              or die encode_utf8('Cannot open ' . $item->unpacked_path);
        }

        my @manfile = <$fd>;
        close $fd;

        # Is it a .so link?
        if ($item->size < $MINIMUM_SHARED_OBJECT_SIZE) {

            my ($i, $first) = (0, $EMPTY);
            do {
                $first = $manfile[$i++] || $EMPTY;
            } while ($first =~ /^\.\\"/ && $manfile[$i]); #");

            unless ($first) {
                $self->pointed_hint('empty-manual-page', $item->pointer);
                return;

            } elsif ($first =~ /^\.so\s+(.+)?$/) {
                my $dest = $1;
                if ($dest =~ m{^([^/]+)/(.+)$}) {

                    my ($manxorlang, $remainder) = ($1, $2);

                    if ($manxorlang !~ /^man\d+$/) {
                        # then it's likely a language subdir, so let's run
                        # the other component through the same check
                        if ($remainder =~ m{^([^/]+)/(.+)$}) {

                            my $rest = $2;
                            $self->pointed_hint(
                                'bad-so-link-within-manual-page',
                                $item->pointer)
                              unless $rest =~ m{^[^/]+\.\d(?:\S+)?(?:\.gz)?$};

                        } else {
                            $self->pointed_hint(
                                'bad-so-link-within-manual-page',
                                $item->pointer);
                        }
                    }

                } else {
                    $self->pointed_hint('bad-so-link-within-manual-page',
                        $item->pointer);
                }
                return;
            }
        }

        # If it's not a .so link, use lexgrog to find out if the
        # man page parses correctly and make sure the short
        # description is reasonable.
        #
        # This check is currently not applied to pages in
        # language-specific hierarchies, because those pages are
        # not currently scanned by mandb (bug #29448), and because
        # lexgrog can't handle pages in all languages at the
        # moment, leading to huge numbers of false negatives. When
        # man-db is fixed, this limitation should be removed.
        if ($page_path =~ m{/man/man\d/}) {

            delete local $ENV{$_}
              for grep { $_ ne 'PATH' && $_ ne 'TMPDIR' } keys %ENV;
            local $ENV{LC_ALL} = 'C.UTF-8';

            my @command = ('lexgrog', $item->unpacked_path);

            my $stdout;
            my $stderr;

            run3(\@command, \undef, \$stdout, \$stderr);

            my $exitcode = $?;
            my $status = ($exitcode >> $WAIT_STATUS_SHIFT);

            $self->pointed_hint('bad-whatis-entry', $item->pointer)
              if $status == 2;

            if ($status != 0 && $status != 2) {
                my $message = "Non-zero status $status from @command";
                $message .= $COLON . $NEWLINE . $stderr
                  if length $stderr;

                warn encode_utf8($message);

            } else {
                my $desc = $stdout;
                $desc =~ s/^[^:]+: \"(.*)\"$/$1/;

                if ($desc =~ /(\S+)\s+-\s+manual page for \1/i) {
                    $self->pointed_hint('useless-whatis-entry',$item->pointer);

                } elsif ($desc =~ /\S+\s+-\s+programs? to do something/i) {
                    $self->pointed_hint('manual-page-from-template',
                        $item->pointer);
                }
            }
        }

        # If it's not a .so link, run it through 'man' to check for errors.
        # If it is in a directory with the standard man layout, cd to the
        # parent directory before running man so that .so directives are
        # processed properly.  (Yes, there are man pages that include other
        # pages with .so but aren't simple links; rbash, for instance.)
        {
            delete local $ENV{$_}
              for grep { $_ ne 'PATH' && $_ ne 'TMPDIR' } keys %ENV;
            local $ENV{LC_ALL} = 'C.UTF-8';

            local $ENV{MANROFFSEQ} = $EMPTY;

            # set back to 80 when Bug#892423 is fixed in groff
            local $ENV{MANWIDTH} = $WIDE_SCREEN;

            my $stdout;
            my $stderr;

            my @command = qw(man --warnings -E UTF-8 -l -Tutf8 -Z);
            push(@command, $item->unpacked_path);

            my $localdir = path($item->unpacked_path)->parent->stringify;
            $localdir =~ s{^(.*)/man\d\b}{$1}s;

            my $savedir = getcwd;
            chdir($localdir)
              or die encode_utf8('Cannot change directory ' . $localdir);

            run3(\@command, \undef, \$stdout, \$stderr);

            my $exitcode = $?;
            my $status = ($exitcode >> $WAIT_STATUS_SHIFT);

            my @lines = split(/\n/, $stderr);

            my $position = 1;
            for my $line (@lines) {

                chomp $line;

                # Devel::Cover causes some annoying deep recursion
                # warnings and sometimes in our child process.
                # Filter them out, but only during coverage.
                next
                  if $ENV{LINTIAN_COVERAGE}
                  && $line =~ m{
                      \A Deep [ ] recursion [ ] on [ ] subroutine [ ]
                      "[^"]+" [ ] at [ ] .*B/Deparse.pm [ ] line [ ]
                      \d+}xsm;

                # ignore progress information from man
                next
                  if $line =~ /^Reformatting/;

                next
                  if $line =~ /^\s*$/;

                # ignore errors from gzip; dealt with elsewhere
                next
                  if $line =~ /^\bgzip\b/;

                # ignore wrapping failures for Asian man pages (groff problem)
                if ($language =~ /^(?:ja|ko|zh)/) {
                    next
                      if $line =~ /warning \[.*\]: cannot adjust line/;
                    next
                      if $line =~ /warning \[.*\]: can\'t break line/;
                }

                # ignore wrapping failures if they contain URLs (.UE is an
                # extension for marking the end of a URL).
                next
                  if $line
                  =~ /:(\d+): warning \[.*\]: (?:can\'t break|cannot adjust) line/
                  && ( $manfile[$1 - 1] =~ m{(?:https?|ftp|file)://.+}i
                    || $manfile[$1 - 1] =~ m{^\s*\.\s*UE\b});

                # ignore common undefined macros from pod2man << Perl 5.10
                next
                  if $line =~ /warning: (?:macro )?\'(?:Tr|IX)\' not defined/;

                $line =~ s/^[^:]+: //;
                $line =~ s/^<standard input>://;

                $self->pointed_hint('groff-message',
                    $item->pointer($position), $line);
            } continue {
                ++$position;
            }

            chdir($savedir)
              or die encode_utf8('Cannot change directory ' . $savedir);

        }

        # Now we search through the whole man page for some common errors
        my $position = 1;
        my $seen_python_traceback;
        for my $line (@manfile) {

            chomp $line;

            next
              if $line =~ /^\.\\\"/; # comments .\"

            if ($line =~ /^\.TH\s/) {

                # title header
                my $consumed = $line;
                $consumed =~ s/ [.]TH \s+ //msx;

                my ($delimited, $after_names) = extract_delimited($consumed);
                unless (length $delimited) {
                    $consumed =~ s/ ^ \s* \S+ , //gmsx;
                    $consumed =~ s/ ^ \s* \S+ //msx;
                    $after_names = $consumed;
                }

                my ($th_section) = extract_delimited($after_names);
                if (length $th_section) {

                    # drop initial delimiter
                    $th_section =~ s/ ^. //msx;

                    # drop final delimiter
                    $th_section =~ s/ .$ //msx;

                    # unescape
                    $th_section =~ s/ [\\](.) /$1/gmsx;

                } elsif (length $after_names
                    && $after_names =~ / ^ \s* (\S+) /msx) {
                    $th_section = $1;
                }

                $self->pointed_hint(
                    'wrong-manual-section',
                    $item->pointer($position),
                    "$fn_section != $th_section"
                )if length $th_section && fc($th_section) ne fc($fn_section);
            }

            if (   ($line =~ m{(/usr/(dict|doc|etc|info|man|adm|preserve)/)})
                || ($line =~ m{(/var/(adm|catman|named|nis|preserve)/)})){
                # FSSTND dirs in man pages
                # regexes taken from checks/files
                $self->pointed_hint('FSSTND-dir-in-manual-page',
                    $item->pointer($position), $1);
            }

            if ($line eq '.SH "POD ERRORS"') {
                $self->pointed_hint('pod-conversion-message',
                    $item->pointer($position));
            }

            if ($line =~ /Traceback \(most recent call last\):/) {
                $self->pointed_hint('python-traceback-in-manpage',
                    $item->pointer)
                  unless $seen_python_traceback;
                $seen_python_traceback = 1;
            }

            # Check for spelling errors if the manpage is English
            my $stag_emitter
              = $self->spelling_tag_emitter('typo-in-manual-page',
                $item->pointer($position));
            check_spelling($self->data, $line,
                $self->group->spelling_exceptions,
                $stag_emitter, 0)
              if $page_path =~ m{/man/man\d/};

        } continue {
            ++$position;
        }
    }

    # most man pages are zipped
    my $bytes;
    if ($item->file_type =~ /gzip compressed/) {

        my $path = $item->unpacked_path;
        gunzip($path => \$bytes)
          or die encode_utf8("gunzip $path failed: $GunzipError");

    } elsif ($item->file_type =~ /^troff/ || $item->file_type =~ /text$/) {
        $bytes = $item->bytes;
    }

    return
      unless length $bytes;

    # another check complains about invalid encoding
    return
      unless valid_utf8($bytes);

    my $contents = decode_utf8($bytes);
    my @lines = split(/\n/, $contents);

    my $position = 1;
    for my $line (@lines) {

        # see Bug#554897 and Bug#507673; exclude string variables
        $self->pointed_hint('acute-accent-in-manual-page',
            $item->pointer($position))
          if $line =~ /\\'/ && $line !~ /^\.\s*ds\s/;

    } continue {
        $position++;
    }

    return;
}

sub installable {
    my ($self) = @_;

    # no man pages in udebs
    return
      if $self->processable->type eq 'udeb';

    my %local_user_executables;
    my %local_admin_executables;

    for my $item (@{$self->processable->installed->sorted_list}) {

        next
          unless $item->is_symlink || $item->is_file;

        my ($name, $path, undef) = fileparse($item->name);

        $local_user_executables{$name} = $item
          if any { $path eq $_ } @user_locations;

        $local_admin_executables{$name} = $item
          if any { $path eq $_ } @admin_locations;
    }

    my %local_executables= (%local_user_executables, %local_admin_executables);
    my @local_commands = keys %local_executables;

    my @direct_reliants
      =@{$self->group->direct_reliants($self->processable) // []};
    my @reliant_files = map { @{$_->installed->sorted_list} } @direct_reliants;

    # for executables, look at packages relying on the current processable
    my %distant_executables;
    for my $item (@reliant_files) {

        next
          unless $item->is_file || $item->is_symlink;

        my ($name, $path, undef) = fileparse($item, qr{\..+$});

        $distant_executables{$name} = $item
          if any { $path eq $_ } (@user_locations, @admin_locations);
    }

    my @distant_commands = keys %distant_executables;
    my @related_commands = (@local_commands, @distant_commands);

    my @direct_prerequisites
      =@{$self->group->direct_dependencies($self->processable) // []};
    my@prerequisite_files
      = map { @{$_->installed->sorted_list} } @direct_prerequisites;

    # for manpages, look at packages the current processable relies upon
    my %distant_manpages;
    for my $item (@prerequisite_files) {

        next
          unless $item->is_file || $item->is_symlink;

        my ($name, $path, undef) = fileparse($item, qr{\..+$});

        next
          unless $path =~ m{^usr/share/man/\S+};

        next
          unless $path =~ m{man\d/$};

        my ($language) = ($path =~ m{/([^/]+)/man\d/$});
        $language //= $EMPTY;
        $language = $EMPTY if $language eq 'man';

        $distant_manpages{$name} //= [];

        push @{$distant_manpages{$name}},
          {file => $item, language => $language};
    }

    my %local_manpages = %{$self->local_manpages};
    my %related_manpages = (%local_manpages, %distant_manpages);

    # provides sorted output
    my $related
      = List::Compare->new(\@local_commands, [keys %related_manpages]);
    my @documented = $related->get_intersection;
    my @manpage_missing = $related->get_Lonly;

    my @english_missing = grep {
        none {$_->{language} eq $EMPTY}
        @{$related_manpages{$_} // []}
    } @documented;

    for my $command (keys %local_admin_executables) {

        my $item = $local_admin_executables{$command};
        my @manpages = @{$related_manpages{$command} // []};

        my @sections = grep { defined } map { $_->{section} } @manpages;
        $self->pointed_hint('manual-page-for-system-command', $item->pointer)
          if $item->is_regular_file
          && any { $_ == $USER_COMMAND_SECTION } @sections;
    }

    $self->pointed_hint('no-english-manual-page', $_->pointer)
      for map {$local_executables{$_}} @english_missing;

    $self->pointed_hint('no-manual-page', $_->pointer)
      for map {$local_executables{$_}} @manpage_missing;

    # surplus manpages only for this package; provides sorted output
    my $local = List::Compare->new(\@related_commands, [keys %local_manpages]);
    my @surplus_manpages = $local->get_Ronly;

    # filter out sub commands, underscore for libreswan; see Bug#947258
    for my $command (@related_commands) {
        @surplus_manpages = grep { !/^$command(?:\b|_)/ } @surplus_manpages;
    }

    for my $manpage (map { @{$local_manpages{$_} // []} } @surplus_manpages) {

        my $item = $manpage->{file};
        my $section = $manpage->{section};

        $self->pointed_hint('spare-manual-page', $item->pointer)
          if $section == $USER_COMMAND_SECTION
          || $section == $SYSTEM_COMMAND_SECTION;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

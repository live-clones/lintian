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

package Lintian::documentation::manual;

use v5.20;
use warnings;
use utf8;
use autodie;

use Cwd qw(getcwd);
use File::Basename;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use IPC::Run3;
use List::Compare;
use List::MoreUtils qw(any none);
use Path::Tiny;
use Text::ParseWords ();
use Unicode::UTF8 qw(valid_utf8 decode_utf8);

use Lintian::Spelling qw(check_spelling);
use Lintian::Util qw(open_gz);

use constant LINTIAN_COVERAGE => ($ENV{'LINTIAN_COVERAGE'}?1:0);

use constant EMPTY => q{};
use constant COLON => q{:};
use constant NEWLINE => qq{\n};

use Moo;
use namespace::clean;

with 'Lintian::Check';

has local_manpages => (is => 'rw', default => sub { {} });

sub spelling_tag_emitter {
    my ($self, @orig_args) = @_;
    return sub {
        return $self->hint(@orig_args, @_);
    };
}

my @user_locations= qw(bin/ usr/bin/ usr/bin/X11/ usr/bin/mh/ usr/games/);
my @admin_locations= qw(sbin/ usr/sbin/);

sub visit_installed_files {
    my ($self, $file) = @_;

    # no man pages in udebs
    return
      if $self->processable->type eq 'udeb';

    if ($file->name =~ m,^usr/share/man/\S+,) {

        $self->hint('manual-page-in-udeb', $file->name)
          if $self->processable->type eq 'udeb';

        if ($file->is_dir) {
            $self->hint('stray-folder-in-manual', $file->name)
              unless $file->name
              =~ m,^usr/(?:X11R6|share)/man/(?:[^/]+/)?(?:man\d/)?$,;

        } elsif ($file->is_file && ($file->operm & 0111)) {
            $self->hint('executable-manual-page', $file->name);
        }
    }

    return
      unless $file->is_file || $file->is_symlink;

    my ($manpage, $page_path, undef) = fileparse($file);

    if ($page_path =~ m{^usr/share/man/$} && $manpage ne EMPTY) {
        $self->hint('odd-place-for-manual-page', $file);
        return;
    }

    # manual page?
    my ($subdir) = ($page_path =~ m{^usr/share/man(/\S+)});
    return
      unless defined $subdir;

    $self->hint('build-path-in-manual', $file)
      if $file =~ m{/_build_} || $file =~ m{_tmp_buildd};

    $self->hint('manual-page-with-generic-name', $file)
      if $file =~ m{/README\.};

    my ($section) = ($subdir =~ m{^.*man(\d)/$});
    unless (defined $section) {
        $self->hint('odd-place-for-manual-page', $file);
        return;
    }

    my ($language) = ($subdir =~ m{^/([^/]+)/man\d/$});
    $language //= EMPTY;

    # The country should not be part of the man page locale
    # directory unless it's one of the known cases where the
    # language is significantly different between countries.
    $self->hint('country-in-manual', $file)
      if $language =~ /_/ && $language !~ /^(?:pt_BR|zh_[A-Z][A-Z])$/;

    my $file_info = $file->file_info;

    my @pieces = split(/\./, $manpage);
    my $ext = pop @pieces;
    if ($ext ne 'gz') {
        push @pieces, $ext;
        $self->hint('uncompressed-manual-page', $file);
    } elsif ($file->is_file) { # so it's .gz... files first; links later
        if ($file_info !~ m/gzip compressed data/) {
            $self->hint('wrong-compression-in-manual-page', $file);
        } elsif ($file_info !~ m/max compression/) {
            $self->hint('poor-compression-in-manual-page',$file);
        }
    }
    my $fn_section = pop @pieces;
    my $section_num = $fn_section;
    if (scalar @pieces && $section_num =~ s/^(\d).*$/$1/) {
        my $bin = join('.', @pieces);
        $self->local_manpages->{$bin} = []
          unless $self->local_manpages->{$bin};
        push @{$self->local_manpages->{$bin}},
          { file => $file, language => $language, section => $section };

        # number of directory and manpage extension equal?
        if ($section_num != $section) {
            $self->hint('odd-place-for-manual-page', $file);
        }
    } else {
        $self->hint('wrong-name-for-manual-page', $file);
    }

    # check symbolic links to other manual pages
    if ($file->is_symlink) {
        if ($file->link =~ m,(^|/)undocumented,) {
            # undocumented link in /usr/share/man -- possibilities
            #    undocumented... (if in the appropriate section)
            #    ../man?/undocumented...
            #    ../../man/man?/undocumented...
            #    ../../../share/man/man?/undocumented...
            #    ../../../../usr/share/man/man?/undocumented...
            if ((
                        $file->link =~ m,^undocumented\.([237])\.gz,
                    and $page_path =~ m,^usr/share/man/man$1,
                )
                or $file->link =~ m,^\.\./man[237]/undocumented\.[237]\.gz$,
                or $file->link
                =~ m,^\.\./\.\./man/man[237]/undocumented\.[237]\.gz$,
                or $file->link
                =~ m,^\.\./\.\./\.\./share/man/man[237]/undocumented\.[237]\.gz$,
                or $file->link
                =~ m,^\.\./\.\./\.\./\.\./usr/share/man/man[237]/undocumented\.[237]\.gz$,
            ) {
                $self->hint('undocumented-manual-page', $file);
            } else {
                $self->hint('broken-link-to-undocumented', $file);
            }
        }
    } else { # not a symlink

        my $fd;
        if ($file_info =~ m/gzip compressed/) {
            $fd = open_gz($file->unpacked_path);
        } else {
            open($fd, '<', $file->unpacked_path);
        }
        my @manfile = <$fd>;
        close $fd;
        # Is it a .so link?
        if ($file->size < 256) {
            my ($i, $first) = (0, '');
            do {
                $first = $manfile[$i++] || '';
            } while ($first =~ /^\.\\"/ && $manfile[$i]); #");

            unless ($first) {
                $self->hint('empty-manual-page', $file);
                return;
            } elsif ($first =~ /^\.so\s+(.+)?$/) {
                my $dest = $1;
                if ($dest =~ m,^([^/]+)/(.+)$,) {
                    my ($manxorlang, $remainder) = ($1, $2);
                    if ($manxorlang !~ /^man\d+$/) {
                        # then it's likely a language subdir, so let's run
                        # the other component through the same check
                        if ($remainder =~ m,^([^/]+)/(.+)$,) {
                            my (undef, $rest) = ($1, $2);
                            if ($rest !~ m,^[^/]+\.\d(?:\S+)?(?:\.gz)?$,) {
                                $self->hint('bad-so-link-within-manual-page',
                                    $file);
                            }
                        } else {
                            $self->hint('bad-so-link-within-manual-page',
                                $file);
                        }
                    }
                } else {
                    $self->hint('bad-so-link-within-manual-page', $file);
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
        if ($page_path =~ m,/man/man\d/,) {

            delete local $ENV{$_}
              for grep { $_ ne 'PATH' && $_ ne 'TMPDIR' } keys %ENV;
            local $ENV{LC_ALL} = 'C.UTF-8';

            my @command = ('lexgrog', $file->unpacked_path);

            my $stdout;
            my $stderr;

            run3(\@command, \undef, \$stdout, \$stderr);

            my $exitcode = $?;
            my $status = ($exitcode >> 8);

            $self->hint('bad-whatis-entry', $file)
              if $status == 2;

            if ($status != 0 && $status != 2) {
                my $message = "Non-zero status $status from @command";
                $message .= COLON . NEWLINE . $stderr
                  if length $stderr;

                warn $message;

            } else {
                my $desc = $stdout;
                $desc =~ s/^[^:]+: \"(.*)\"$/$1/;

                if ($desc =~ /(\S+)\s+-\s+manual page for \1/i) {
                    $self->hint('useless-whatis-entry', $file);

                } elsif ($desc =~ /\S+\s+-\s+programs? to do something/i) {
                    $self->hint('manual-page-from-template', $file);
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

            local $ENV{MANROFFSEQ} = EMPTY;

            # set back to 80 when Bug#892423 is fixed in groff
            local $ENV{MANWIDTH} = 120;

            my $stdout;
            my $stderr;

            my @command = qw(man --warnings -E UTF-8 -l -Tutf8 -Z);
            push(@command, $file->unpacked_path);

            my $localdir = path($file->unpacked_path)->parent->stringify;
            $localdir =~ s{^(.*)/man\d\b}{$1}s;

            my $savedir = getcwd;
            chdir($localdir);

            run3(\@command, \undef, \$stdout, \$stderr);

            my $exitcode = $?;
            my $status = ($exitcode >> 8);

            my @lines = split(/\n/, $stderr);

            for my $line (@lines) {

                chomp $line;

                # Devel::Cover causes some annoying deep recursion
                # warnings and sometimes in our child process.
                # Filter them out, but only during coverage.
                next
                  if LINTIAN_COVERAGE
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
                  && ( $manfile[$1 - 1] =~ m,(?:https?|ftp|file)://.+,i
                    || $manfile[$1 - 1] =~ m,^\s*\.\s*UE\b,);

                # ignore common undefined macros from pod2man << Perl 5.10
                next
                  if $line =~ /warning: (?:macro )?\'(?:Tr|IX)\' not defined/;

                $line =~ s/^[^:]+: //;
                $line =~ s/^<standard input>://;

                $self->hint('groff-message', $file, $line);
            }

            chdir($savedir);

        }

        # Now we search through the whole man page for some common errors
        my $lc = 0;
        my $stag_emitter
          = $self->spelling_tag_emitter('typo-in-manual-page', $file);
        foreach my $line (@manfile) {
            $lc++;
            chomp $line;
            next if $line =~ /^\.\\\"/; # comments .\"
            if ($line =~ /^\.TH\s/) { # header
                my @th_fields= Text::ParseWords::parse_line('\s+', 0, $line);
                my $pkgname_idx = 1;
                # Iterate over possible package names.  If there is
                # more than one, they will be separated by a comma and
                # a whitespace.  In case we find the comma, we advance
                # $pkgname_idx.
                while ((substr($th_fields[$pkgname_idx], -1) // EMPTY) eq ','){
                    $pkgname_idx++;
                }
                # We're now at the last package, so we should be able
                # to obtain the manpage section number by incrementing
                # 1 to the index.
                my $th_section = $th_fields[++$pkgname_idx];
                if ($th_section && (lc($fn_section) ne lc($th_section))) {
                    $self->hint('wrong-manual-section',
                        "$file:$lc $fn_section != $th_section");
                }
            }
            if (   ($line =~ m,(/usr/(dict|doc|etc|info|man|adm|preserve)/),)
                || ($line =~ m,(/var/(adm|catman|named|nis|preserve)/),)){
                # FSSTND dirs in man pages
                # regexes taken from checks/files
                $self->hint('FSSTND-dir-in-manual-page', "$file:$lc $1");
            }
            if ($line eq '.SH "POD ERRORS"') {
                $self->hint('pod-conversion-message', "$file:$lc");
            }
            # Check for spelling errors if the manpage is English
            check_spelling($self->profile, $line,
                $self->group->spelling_exceptions,
                $stag_emitter, 0)
              if ($page_path =~ m,/man/man\d/,);
        }
    }

    # most man pages are zipped
    my $bytes;
    if ($file->file_info =~ /gzip compressed/) {

        my $path = $file->unpacked_path;
        gunzip($path => \$bytes)
          or die "gunzip $path failed: $GunzipError";

    } elsif ($file->file_info =~ /^troff/ || $file->file_info =~ /text$/) {
        $bytes = $file->bytes;
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
        $self->hint('acute-accent-in-manual-page',
            $file->name . COLON . $position)
          if $line =~ /\\'/ && $line !~ /^\.\s*ds\s/;

    } continue {
        $position++;
    }

    return;
}

sub breakdown_installed_files {
    my ($self) = @_;

    # no man pages in udebs
    return
      if $self->processable->type eq 'udeb';

    my %local_user_executables;
    my %local_admin_executables;

    for my $file ($self->processable->installed->sorted_list) {

        next
          unless $file->is_symlink || $file->is_file;

        my ($name, $path, undef) = fileparse($file->name);

        $local_user_executables{$name} = $file
          if any { $path eq $_ } @user_locations;

        $local_admin_executables{$name} = $file
          if any { $path eq $_ } @admin_locations;
    }

    my %local_executables= (%local_user_executables, %local_admin_executables);
    my @local_commands = keys %local_executables;

    my @direct_reliants
      =@{$self->group->direct_reliants($self->processable) // []};
    my@reliant_files = map { $_->installed->sorted_list } @direct_reliants;

    # for executables, look at packages relying on the current processable
    my %distant_executables;
    for my $file (@reliant_files) {

        next
          unless $file->is_file || $file->is_symlink;

        my ($name, $path, undef) = fileparse($file, qr{\..+$});

        $distant_executables{$name} = $file
          if any { $path eq $_ } (@user_locations, @admin_locations);
    }

    my @distant_commands = keys %distant_executables;
    my @related_commands = (@local_commands, @distant_commands);

    my @direct_prerequisites
      =@{$self->group->direct_dependencies($self->processable) // []};
    my@prerequisite_files
      = map { $_->installed->sorted_list } @direct_prerequisites;

    # for manpages, look at packages the current processable relies upon
    my %distant_manpages;
    for my $file (@prerequisite_files) {

        next
          unless $file->is_file || $file->is_symlink;

        my ($name, $path, undef) = fileparse($file, qr{\..+$});

        next
          unless $path =~ m{^usr/share/man/\S+};

        next
          unless $path =~ m{man\d/$};

        my ($language) = ($path =~ m{/([^/]+)/man\d/$});
        $language //= EMPTY;
        $language = EMPTY if $language eq 'man';

        $distant_manpages{$name} //= [];

        push @{$distant_manpages{$name}},
          {file => $file, language => $language};
    }

    my %local_manpages = %{$self->local_manpages};
    my %related_manpages = (%local_manpages, %distant_manpages);

    # provides sorted output
    my $related
      = List::Compare->new(\@local_commands, [keys %related_manpages]);
    my @documented = $related->get_intersection;
    my @manpage_missing = $related->get_Lonly;

    my @english_missing = grep {
        none {$_->{language} eq EMPTY}
        @{$related_manpages{$_} // []}
    } @documented;

    for my $command (keys %local_admin_executables) {

        my $file = $local_admin_executables{$command};
        my @manpages = @{$related_manpages{$command} // []};

        my @sections = grep { defined } map { $_->{section} } @manpages;
        $self->hint('manual-page-for-system-command', $file)
          if $file->is_regular_file
          && any { $_ == 1 } @sections;
    }

    $self->hint('no-english-manual-page', $_)
      for map {$local_executables{$_}} @english_missing;

    $self->hint('no-manual-page', $_)
      for map {$local_executables{$_}} @manpage_missing;

    # surplus manpages only for this package; provides sorted output
    my $local = List::Compare->new(\@related_commands, [keys %local_manpages]);
    my @surplus_manpages = $local->get_Ronly;

    for my $manpage (map { @{$local_manpages{$_} // []} } @surplus_manpages) {

        my $file = $manpage->{file};
        my $section = $manpage->{section};

        $self->hint('spare-manual-page', $file)
          if $section == 1 || $section == 8;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

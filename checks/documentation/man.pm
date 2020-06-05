# documentation/man -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz
# Copyright © 2019 Felix Lechner
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

package Lintian::documentation::man;

use v5.20;
use warnings;
use utf8;
use autodie;

use File::Basename;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use List::Compare;
use List::MoreUtils qw(any none);
use Text::ParseWords ();
use Unicode::UTF8 qw(valid_utf8 decode_utf8);

use Lintian::Spelling qw(check_spelling);
use Lintian::Util qw(clean_env do_fork drain_pipe open_gz);

use constant LINTIAN_COVERAGE => ($ENV{'LINTIAN_COVERAGE'}?1:0);

use constant EMPTY => q{};
use constant COLON => q{:};

use Moo;
use namespace::clean;

with 'Lintian::Check';

has local_manpages => (is => 'rw', default => sub { {} });

has running_man => (is => 'rw', default => sub { [] });
has running_lexgrog => (is => 'rw', default => sub { [] });

sub spelling_tag_emitter {
    my ($self, @orig_args) = @_;
    return sub {
        return $self->tag(@orig_args, @_);
    };
}

my @user_locations= qw(bin/ usr/bin/ usr/bin/X11/ usr/bin/mh/ usr/games/);
my @admin_locations= qw(sbin/ usr/sbin/);

sub files {
    my ($self, $file) = @_;

    # no man pages in udebs
    return
      if $self->type eq 'udeb';

    if ($file->name =~ m,^usr/share/man/\S+,) {

        $self->tag('manpage-in-udeb', $file->name)
          if $self->type eq 'udeb';

        if ($file->is_dir) {
            $self->tag('stray-directory-in-manpage-directory', $file->name)
              unless $file->name
              =~ m,^usr/(?:X11R6|share)/man/(?:[^/]+/)?(?:man\d/)?$,;

        } elsif ($file->is_file && ($file->operm & 0111)) {
            $self->tag('executable-manpage', $file->name);
        }
    }

    return
      unless $file->is_file || $file->is_symlink;

    my ($manpage, $path, undef) = fileparse($file);

    if ($path =~ m{^usr/share/man/$} && $manpage ne EMPTY) {
        $self->tag('manpage-in-wrong-directory', $file);
        return;
    }

    # manual page?
    my ($subdir) = ($path =~ m{^usr/share/man(/\S+)});
    return
      unless defined $subdir;

    $self->tag('manpage-named-after-build-path', $file)
      if $file =~ m{/_build_} || $file =~ m{_tmp_buildd};

    $self->tag('manpage-has-overly-generic-name', $file)
      if $file =~ m{/README\.};

    my ($section) = ($subdir =~ m{^.*man(\d)/$});
    unless (defined $section) {
        $self->tag('manpage-in-wrong-directory', $file);
        return;
    }

    my ($language) = ($subdir =~ m{^/([^/]+)/man\d/$});
    $language //= EMPTY;

    # The country should not be part of the man page locale
    # directory unless it's one of the known cases where the
    # language is significantly different between countries.
    $self->tag('manpage-locale-dir-country-specific', $file)
      if $language =~ /_/ && $language !~ /^(?:pt_BR|zh_[A-Z][A-Z])$/;

    my $file_info = $file->file_info;

    my @pieces = split(/\./, $manpage);
    my $ext = pop @pieces;
    if ($ext ne 'gz') {
        push @pieces, $ext;
        $self->tag('manpage-not-compressed', $file);
    } elsif ($file->is_file) { # so it's .gz... files first; links later
        if ($file_info !~ m/gzip compressed data/) {
            $self->tag('manpage-not-compressed-with-gzip', $file);
        } elsif ($file_info !~ m/max compression/) {
            $self->tag('manpage-not-compressed-with-max-compression',$file);
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
            $self->tag('manpage-in-wrong-directory', $file);
        }
    } else {
        $self->tag('manpage-has-wrong-extension', $file);
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
                    and $path =~ m,^usr/share/man/man$1,
                )
                or $file->link =~ m,^\.\./man[237]/undocumented\.[237]\.gz$,
                or $file->link
                =~ m,^\.\./\.\./man/man[237]/undocumented\.[237]\.gz$,
                or $file->link
                =~ m,^\.\./\.\./\.\./share/man/man[237]/undocumented\.[237]\.gz$,
                or $file->link
                =~ m,^\.\./\.\./\.\./\.\./usr/share/man/man[237]/undocumented\.[237]\.gz$,
            ) {
                $self->tag('link-to-undocumented-manpage', $file);
            } else {
                $self->tag('bad-link-to-undocumented-manpage', $file);
            }
        }
    } else { # not a symlink
        my $unpacked_path = $file->unpacked_path;
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
                $self->tag('empty-manual-page', $file);
                return;
            } elsif ($first =~ /^\.so\s+(.+)?$/) {
                my $dest = $1;
                if ($dest =~ m,^([^/]+)/(.+)$,) {
                    my ($manxorlang, $rest) = ($1, $2);
                    if ($manxorlang !~ /^man\d+$/) {
                        # then it's likely a language subdir, so let's run
                        # the other component through the same check
                        if ($rest =~ m,^([^/]+)/(.+)$,) {
                            my (undef, $rest) = ($1, $2);
                            if ($rest !~ m,^[^/]+\.\d(?:\S+)?(?:\.gz)?$,) {
                                $self->tag('bad-so-link-within-manual-page',
                                    $file);
                            }
                        } else {
                            $self->tag('bad-so-link-within-manual-page',$file);
                        }
                    }
                } else {
                    $self->tag('bad-so-link-within-manual-page', $file);
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
        if ($path =~ m,/man/man\d/,) {
            my $pid = open(my $lexgrog_fd, '-|');
            if ($pid == 0) {
                clean_env;
                open(STDERR, '>&', \*STDOUT);
                exec('lexgrog', $unpacked_path)
                  or die "exec lexgrog failed: $!";
            }
            if (@{$self->running_lexgrog} > 2) {
                $self->process_lexgrog_output($self->running_lexgrog);
            }
            # lexgrog can have a high start up time, so revisit
            # this later.
            push(@{$self->running_lexgrog}, [$file, $lexgrog_fd, $pid]);
        }

        # If it's not a .so link, run it through 'man' to check for errors.
        # If it is in a directory with the standard man layout, cd to the
        # parent directory before running man so that .so directives are
        # processed properly.  (Yes, there are man pages that include other
        # pages with .so but aren't simple links; rbash, for instance.)
        my @cmd = qw(man --warnings -E UTF-8 -l -Tutf8 -Z);
        my $dir;
        if ($unpacked_path =~ m,^(.*)/(man\d/.*)$,) {
            $dir = $1;
            push @cmd, $2;
        } else {
            push(@cmd, $unpacked_path);
        }
        my ($read, $write);
        pipe($read, $write);
        my $pid = do_fork();
        if ($pid == 0) {
            clean_env;
            close STDOUT;
            close $read;
            open(STDOUT, '>', '/dev/null');
            open(STDERR, '>&', $write);
            if ($dir) {
                chdir($dir);
            }
            $ENV{MANROFFSEQ} = '';
            $ENV{MANWIDTH} = 80;
            exec { $cmd[0] } @cmd
              or die "cannot run man -E UTF-8 -l: $!";
        } else {
            # parent - close write end
            close $write;
        }

        if (@{$self->running_man} > 3) {
            $self->process_man_output($self->running_man);
        }
        # man can have a high start up time, so revisit this
        # later.
        push(@{$self->running_man},[$file, $read, $pid, $language, \@manfile]);

        # Now we search through the whole man page for some common errors
        my $lc = 0;
        my $stag_emitter
          = $self->spelling_tag_emitter('spelling-error-in-manpage', $file);
        foreach my $line (@manfile) {
            $lc++;
            chomp $line;
            next if $line =~ /^\.\\\"/; # comments .\"
            if ($line =~ /^\.TH\s/) { # header
                my (undef, undef, $th_section, undef)
                  = Text::ParseWords::parse_line('\s+', 0, $line);
                if ($th_section && (lc($fn_section) ne lc($th_section))) {
                    $self->tag('manpage-section-mismatch',
                        "$file:$lc $fn_section != $th_section");
                }
            }
            if (   ($line =~ m,(/usr/(dict|doc|etc|info|man|adm|preserve)/),)
                || ($line =~ m,(/var/(adm|catman|named|nis|preserve)/),)){
                # FSSTND dirs in man pages
                # regexes taken from checks/files
                $self->tag('FSSTND-dir-in-manual-page', "$file:$lc $1");
            }
            if ($line eq '.SH "POD ERRORS"') {
                $self->tag('manpage-has-errors-from-pod2man', "$file:$lc");
            }
            # Check for spelling errors if the manpage is English
            check_spelling($line, $self->group->spelling_exceptions,
                $stag_emitter, 0)
              if ($path =~ m,/man/man\d/,);
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

    unless (valid_utf8($bytes)) {
        $self->tag('national-encoding-in-manpage', $file->name);
        return;
    }

    my $contents = decode_utf8($bytes);
    my @lines = split(/\n/, $contents);

    my $position = 1;
    for my $line (@lines) {

        # see Bug#554897 and Bug#507673; exclude string variables
        $self->tag('acute-accent-in-manpage', $file->name . COLON . $position)
          if $line =~ /\\'/ && $line !~ /^\.\s*ds\s/;

    } continue {
        $position++;
    }

    return;
}

sub breakdown {
    my ($self) = @_;

    # no man pages in udebs
    return
      if $self->type eq 'udeb';

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
        $self->tag('command-in-sbin-has-manpage-in-incorrect-section', $file)
          if $file->is_regular_file
          && any { $_ == 1 } @sections;
    }

    $self->tag('binary-without-english-manpage', $_)
      for map {$local_executables{$_}} @english_missing;

    $self->tag('binary-without-manpage', $_)
      for map {$local_executables{$_}} @manpage_missing;

    # surplus manpages only for this package; provides sorted output
    my $local = List::Compare->new(\@related_commands, [keys %local_manpages]);
    my @surplus_manpages = $local->get_Ronly;

    for my $manpage (map { @{$local_manpages{$_} // []} } @surplus_manpages) {

        my $file = $manpage->{file};
        my $section = $manpage->{section};

        $self->tag('manpage-without-executable', $file)
          if $section == 1 || $section == 8;
    }

    # If we have any running sub processes, wait for them here.
    $self->process_lexgrog_output($self->running_lexgrog)
      if @{$self->running_lexgrog};
    $self->process_man_output($self->running_man) if @{$self->running_man};

    return;
}

sub process_lexgrog_output {
    my ($self, $running) = @_;
    for my $lex_proc (@{$running}) {
        my ($file, $lexgrog_fd, undef) = @{$lex_proc};
        my $desc = <$lexgrog_fd>;
        $desc =~ s/^[^:]+: \"(.*)\"$/$1/;
        if ($desc =~ /(\S+)\s+-\s+manual page for \1/i) {
            $self->tag('manpage-has-useless-whatis-entry', $file);
        } elsif ($desc =~ /\S+\s+-\s+programs? to do something/i) {
            $self->tag('manpage-is-dh_make-template', $file);
        }
        drain_pipe($lexgrog_fd);
        eval {close($lexgrog_fd);};
        if (my $err = $@) {
            # Problem closing the pipe?
            die "close pipe: $err: $!"
              if $err->errno;
            # No, then lexgrog returned with a non-zero exit code.
            $self->tag('manpage-has-bad-whatis-entry', $file);
        }
    }
    @{$running} = ();
    return;
}

sub process_man_output {
    my ($self, $running) = @_;
    for my $man_proc (@{$running}) {
        my ($file, $read, $pid, $language, $contents) = @{$man_proc};
        while (<$read>) {
            # Devel::Cover causes some annoying deep recursion
            # warnings and sometimes in our child process.
            # Filter them out, but only during coverage.
            next if LINTIAN_COVERAGE and m{
                    \A Deep [ ] recursion [ ] on [ ] subroutine [ ]
                    "[^"]+" [ ] at [ ] .*B/Deparse.pm [ ] line [ ]
                   \d+}xsm;
            # ignore progress information from man
            next if /^Reformatting/;
            next if /^\s*$/;
            # ignore errors from gzip, will be dealt with at other places
            next if /^(?:man|gzip)/;
            # ignore wrapping failures for Asian man pages (groff problem)
            if ($language =~ /^(?:ja|ko|zh)/) {
                next if /warning \[.*\]: cannot adjust line/;
                next if /warning \[.*\]: can\'t break line/;
            }
            # ignore wrapping failures if they contain URLs (.UE is an
            # extension for marking the end of a URL).
            next
              if/:(\d+): warning \[.*\]: (?:can\'t break|cannot adjust) line/
              and ($contents->[$1 - 1] =~ m,(?:https?|ftp|file)://.+,i
                or $contents->[$1 - 1] =~ m,^\s*\.\s*UE\b,);
            # ignore common undefined macros from pod2man << Perl 5.10
            next if /warning: (?:macro )?\'(?:Tr|IX)\' not defined/;
            chomp;
            s/^[^:]+: //;
            s/^<standard input>://;
            $self->tag('manpage-has-errors-from-man', $file, $_);
            last;
        }
        close($read);
        # reap man process
        waitpid($pid, 0);
    }
    @{$running} = ();
    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

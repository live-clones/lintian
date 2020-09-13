# -*- perl -*- Lintian::Index::Objdump
#
# Copyright © 1998 Christian Schwarz
# Copyright © 2008 Adam D. Barratt
# Copyright © 2017-2018 Chris Lamb <lamby@debian.org>
# Copyright © 2020 Felix Lechner
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::Index::Objdump;

use v5.20;
use warnings;
use utf8;
use autodie;

use Cwd;
use IPC::Run3;
use Path::Tiny;

use constant EMPTY => q{};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Index::Objdump - binary symbol information.

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Index::Objdump binary symbol information.

=head1 INSTANCE METHODS

=over 4

=item add_objdump

=cut

sub add_objdump {
    my ($self) = @_;

    my $savedir = getcwd;
    chdir($self->basedir);

    my @files = grep { $_->is_file } $self->sorted_list;
    for my $file (@files) {

        # must be elf or static library
        next
          unless $file->file_info =~ m/\bELF\b/
          || ( $file->file_info =~ m/\bcurrent ar archive\b/
            && $file->name =~ m/\.a$/);

        my @command = (qw{readelf -WltdVs}, $file->name);
        my $output;
        my $stderr;

        run3(\@command, \undef, \$output, \$stderr);
        my $parsed = parse_output($output . $stderr, $file->name);

        $file->objdump($parsed);
    }

    chdir($savedir);

    return;
}

=item parse_output

=cut

sub parse_output {
    my ($from_readelf, $filename) = @_;

    my (@sections, @symbol_versions);
    my @dyn_symbols;
    my %program_headers;
    my $bin;
    my $truncated = 0;
    my $section = '';

    # List of named sections, which are collected
    my %COLLECT_SECTIONS = map { $_ => 1 } qw(
      .comment
      .note
    );

    my $COLLECT_SECTIONS_REGEX = qr/^\.z?debug_/;
    my $static_lib_issues = 0;

    my $parsed;
    my @lines = split(/\n/, $from_readelf);
    while (defined(my $line = shift @lines)) {

        chomp $line;

        # Skip leading empty lines (readelf spits out an empty line before
        # the first entry).
        next if not $bin and not $line;

        if (not $bin and $line !~ m/^File: ./o) {
         # Special case - readelf will not prefix the output with "File:
         # $name" if it only gets one ELF file argument, so act as if it did...
         # (but it does "the right thing" if passed a static lib >.>)
         #
         # - In fact, if readelf always emitted that File: header, we could
         #   simply use xargs directly on readelf and just parse its output
         #   in the loop below.
            $bin = $filename;
            $parsed .= "Filename: $bin\n";

        }

        if ($line =~ m/^File: (.+)$/) {
            my $file = $1;

            $parsed
              .= finish_file(\@sections, \@dyn_symbols, \@symbol_versions);

            # Add a newline to end the current paragraph
            $parsed .= "\n";

            # reset variables
            @sections = ();
            @symbol_versions = ();
            @dyn_symbols = ();
            $truncated = 0;
            $section = '';
            %program_headers = ();
            $bin = '';

            $bin = $file;
            $parsed .= "Filename: $bin\n";

        } elsif ($line
            =~ m/^readelf: Error: Reading (0x)?[0-9a-fA-F]+ bytes extends past end of file for section headers/
            or $line
            =~ m/^readelf: Error: Unable to read in 0x[0-9a-fA-F]+ bytes of/
            or $line
            =~ m/^readelf: Error: .*: Failed to read .*(?:magic number|file header)/
        ) {
       # Various errors for corrupt / broken files.  Note, readelf may spit out
       # multiple errors per file, hence the "unless".
            $parsed .= "Broken: yes\n" unless $truncated++;
            next;
        } elsif ($line =~ m/^readelf: Error: Not an ELF file/) {
            # Some upstreams like to create valid ar archives with the ".a"
            # extensions and fill them with poems rather than object files.
            #
            # Possibly a reference to afl...
            $static_lib_issues++ if $bin =~ m{\([^/\\)]++\)$};
            next;
        } elsif ($line =~ m/^Elf file type is (\S+)/) {
            $parsed .= "Elf-Type: $1\n";
            next;
        } elsif ($line =~ m/^Program Headers:/) {
            $section = 'PH';
            $parsed .= "Program-Headers:\n";
        } elsif ($line =~ m/^Section Headers:/) {
            $section = 'SH';
            $parsed .= "Section-Headers:\n";
        } elsif ($line =~ m/^Dynamic section at offset .*:/) {
            $section = 'DS';
            $parsed .= "Dynamic-Section:\n";
        } elsif ($line =~ m/^Version symbols section /) {
            $section = 'VS';
        } elsif ($line =~ m/^Symbol table '.dynsym'/) {
            $section = 'DS';
        } elsif ($line =~ m/^Symbol table/) {
            $section = '';
        } elsif ($line =~ m/^\s*$/) {
            $section = '';
        } elsif ($line =~ m/^\s*(\S+)\s*(?:(?:\S+\s+){4})\S+\s(...)/
            and $section eq 'PH') {
            my ($header, $flags) = ($1, $2);
            $header =~ s/^GNU_//g;
            next if $header eq 'Type';

            my $newflags = '';
            my $redo = 0;
            my $extra = '';
            $newflags .= ($flags =~ m/R/) ? 'r' : '-';
            $newflags .= ($flags =~ m/W/) ? 'w' : '-';
            $newflags .= ($flags =~ m/E/) ? 'x' : '-';

            $program_headers{$header} = $newflags;

            if ($header eq 'INTERP') {
                # Check if the next line is the "requesting an interpreter"
                # (readelf appears to always emit on the next line if at all)
                my $next = shift @lines;
                if ($next =~ m,\[Requesting program interpreter:\s([^\]]+)\],){
                    $extra .= " interp=$1";
                } else {
                    # Nope, give it back
                    $redo = 1;
                    $line = $next;
                }
            }

            $parsed .= "  $header flags=${newflags}$extra\n";

            redo if $redo;
            next;

        } elsif ($line =~ m/^\s*\[\s*(\d+)\] (\S+)(?:\s|\Z)/
            and $section eq 'SH') {
            my $section = $2;
            $sections[$1] = $section;
            # We need sections as well (e.g. for incomplete stripping)
            $parsed .= " $section\n"
              if exists($COLLECT_SECTIONS{$section})
              or$section =~ $COLLECT_SECTIONS_REGEX;
        } elsif ($line
            =~ m/^\s*0x(?:[0-9A-F]+)\s+\((.*?)\)\s+([\x21-\x7f][\x20-\x7f]*)\Z/i
            and $section eq 'DS') {
            my ($type, $value) = ($1, $2);
            my $keep = 0;

            if ($type eq 'RPATH' or $type eq 'RUNPATH') {
                $value =~ s/.*\[//;
                $value =~ s/\]\s*$//;
                $keep = 1;
            } elsif ($type eq 'TEXTREL' or $type eq 'DEBUG') {
                $keep = 1;
            } elsif ($type eq 'FLAGS_1') {
                # Will contain "NOW" if the binary was built with -Wl,-z,now
                $keep = 1;
                $value =~ s/^Flags:\s*//i;
            } elsif (($type eq 'FLAGS' and $value =~ m/\bBIND_NOW\b/)
                or $type eq 'BIND_NOW') {
                # Variants of bindnow
                $type = 'FLAGS_1';
                $value = 'NOW';
                $keep = 1;
            }
            $keep = 1
              if $value =~ s/^(?:Shared library|Library soname): \[(.*)\]/$1/;
            $parsed .= "  $type   $value\n" if $keep;
        } elsif (
            $line =~ m/^\s*[0-9a-f]+: \s* \S+ \s* (?:\(\S+\))? (?:\s|\Z)/xi
            and $section eq 'VS') {
            while ($line =~ m/([0-9a-f]+h?)\s*(?:\((\S+)\))?(?:\s|\Z)/gci) {
                my ($vernum, $verstring) = ($1, $2);
                $verstring ||= '';
                if ($vernum =~ m/h$/) {
                    $verstring = "($verstring)";
                }
                push @symbol_versions, $verstring;
            }
        } elsif ($line
            =~ m/^\s*(\d+):\s*[0-9a-f]+\s+\d+\s+(?:(?:\S+\s+){3})(?:\[.*\]\s+)?(\S+)\s+(.*)\Z/
            and $section eq 'DS') {
           # We (sometimes) need to read the "Version symbols section" first to
           # use this data and readelf tends to print after this section, so
           # save for later.
            push(@dyn_symbols, [$1, $2, $3]);

        } elsif ($line =~ m/^There is no dynamic section in this file/
            and exists $program_headers{DYNAMIC}) {
            # The headers declare a dynamic section but it's
            # empty.
            $parsed .= "Bad-Dynamic-Table: Yes\n";
        }
    }

    # Finish the last file
    $parsed .= finish_file(\@sections, \@dyn_symbols, \@symbol_versions);

    # Add a newline to end the current paragraph
    $parsed .= "\n";

    return $parsed;
}

=item finish_file

=cut

sub finish_file {
    my ($sections, $dyn_symbols, $symbol_versions) = @_;

    return EMPTY
      unless @{$dyn_symbols};

    my $parsed .= "Dynamic-Symbols:\n";

    for my $dynsym (@{$dyn_symbols}) {
        my ($symnum, $seg, $sym) = @{$dynsym};
        my $ver;

        if ($sym =~ m/^(.*)@(.*) \(.*\)$/) {
            $sym = $1;
            $ver = $2;
        } elsif (@{$symbol_versions} == 0) {
            # No versioned symbols...
            $ver = '';
        } else {
            $ver = $symbol_versions->[$symnum];

            if ($ver eq '*local*' or $ver eq '*global*') {
                if ($seg eq 'UND') {
                    $ver = '   ';
                } else {
                    $ver = 'Base';
                }
            } elsif ($ver eq '()') {
                $ver = '(Base)';
            }
        }

        # Skip "nameless" symbols - happens once or twice
        # for regular binaries.
        next if $sym eq q{};

        if ($seg =~ m/^\d+$/ and defined $sections->[$seg]) {
            $seg = $sections->[$seg];
        }
        # We only care about undefined symbols and symbols in
        # the .text segment.
        next if $seg ne 'UND' and $seg ne '.text';

        $parsed .= " $seg $ver $sym\n";
    }

    return $parsed;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

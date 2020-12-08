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
use Unicode::UTF8 qw(encode_utf8 decode_utf8);

use constant EMPTY => q{};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Index::Objdump - binary symbol information.

=head1 SYNOPSIS

    use Lintian::Index;

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

    # must be ELF or static library
    my @with_objects = grep {
        $_->file_info =~ /\bELF\b/
          || ( $_->file_info =~ /\bcurrent ar archive\b/
            && $_->name =~ /\.a$/)
    } @files;

    for my $file (@with_objects) {

        my @command = (
            qw{readelf --wide --segments --dynamic --section-details --symbols --version-info},
            $file->name
        );
        my $combined;

        run3(\@command, \undef, \$combined, \$combined);

        $combined = decode_utf8($combined)
          if length $combined;

        # each object file in an archive gets its own File section
        my @per_files = split(/^(File): (.*)$/m, $combined);
        shift @per_files while @per_files && $per_files[0] ne 'File';

        @per_files = ($combined)
          unless @per_files;

        # Special case - readelf will not prefix the output with "File:
        # $name" if it only gets one ELF file argument, so act as if it did...
        # (but it does "the right thing" if passed a static lib >.>)
        #
        # - In fact, if readelf always emitted that File: header, we could
        #   simply use xargs directly on readelf and just parse its output
        #   in the loop below.
        if (@per_files == 1) {
            unshift(@per_files, $file->name);
            unshift(@per_files, 'File');
        }

        die encode_utf8(
            "Parsed data from readelf is not a multiple of three for $file")
          unless @per_files % 3 == 0;

        my $parsed;
        while (defined(my $fixed = shift @per_files)) {

            die encode_utf8("Unknown output from readelf for $file")
              unless $fixed eq 'File';

            my $recorded_name = shift @per_files;
            die encode_utf8("No file name from readelf for $file")
              unless length $file;

            my ($container, $member) = ($recorded_name =~ /^(.*)\(([^)]+)\)$/);

            $container = $recorded_name
              unless defined $container && defined $member;

            die encode_utf8(
                "Container not same as file name ($container vs $file)")
              unless $container eq $file->name;

            my $per_file = shift @per_files;

            # ignore empty archives, such as in musl-dev_1.2.1-1_amd64.deb
            next
              unless length $per_file;

            $parsed .= parse_per_file($per_file, $recorded_name);
        }

        $file->objdump($parsed);
    }

    chdir($savedir);

    return;
}

=item parse_per_file

=cut

sub parse_per_file {
    my ($from_readelf, $filename) = @_;

    my @sections;
    my @symbol_versions;
    my @dynamic_symbols;
    my %program_headers;
    my $truncated = 0;
    my $elf_section = EMPTY;
    my $static_lib_issues = 0;

    my $parsed = "Filename: $filename\n";

    my @lines = split(/\n/, $from_readelf);
    while (defined(my $line = shift @lines)) {

        if ($line
            =~ /^readelf: Error: Reading (0x)?[0-9a-fA-F]+ bytes extends past end of file for section headers/
            || $line
            =~ /^readelf: Error: Unable to read in 0x[0-9a-fA-F]+ bytes of/
            || $line
            =~ /^readelf: Error: .*: Failed to read .*(?:magic number|file header)/
        ) {
       # Various errors for corrupt / broken files.  Note, readelf may spit out
       # multiple errors per file, hence the "unless".
            $parsed .= "Broken: yes\n"
              unless $truncated++;

            next;

        } elsif ($line =~ /^readelf: Error: Not an ELF file/) {
            # Some upstreams like to create valid ar archives with the ".a"
            # extensions and fill them with poems rather than object files.
            #
            # Possibly a reference to afl...
            $static_lib_issues++
              if $filename =~ m{\([^/\\)]++\)$};

            next;

        } elsif ($line =~ /^Elf file type is (\S+)/) {
            $parsed .= "Elf-Type: $1\n";
            next;

        } elsif ($line =~ /^Program Headers:/) {
            $elf_section = 'PH';
            $parsed .= "Program-Headers:\n";

        } elsif ($line =~ /^Section Headers:/) {
            $elf_section = 'SH';
            $parsed .= "Section-Headers:\n";

        } elsif ($line =~ /^Dynamic section at offset .*:/) {
            $elf_section = 'DS';
            $parsed .= "Dynamic-Section:\n";

        } elsif ($line =~ /^Version symbols section /) {
            $elf_section = 'VS';

        } elsif ($line =~ /^Symbol table '.dynsym'/) {
            $elf_section = 'DS';

        } elsif ($line =~ /^Symbol table/) {
            $elf_section = EMPTY;

        } elsif ($line =~ /^\s*$/) {
            $elf_section = EMPTY;

        } elsif ($line =~ /^\s*(\S+)\s*(?:(?:\S+\s+){4})\S+\s(...)/
            and $elf_section eq 'PH') {

            my $header = $1;
            my $flags = $2;

            $header =~ s/^GNU_//g;

            next
              if $header eq 'Type';

            my $extra = EMPTY;

            my $newflags = EMPTY;
            $newflags .= ($flags =~ m/R/) ? 'r' : '-';
            $newflags .= ($flags =~ m/W/) ? 'w' : '-';
            $newflags .= ($flags =~ m/E/) ? 'x' : '-';

            $program_headers{$header} = $newflags;

            if ($header eq 'INTERP' && @lines) {
                # Check if the next line is the "requesting an interpreter"
                # (readelf appears to always emit on the next line if at all)
                my $next_line = $lines[0];

                if ($next_line
                    =~ m{\[Requesting program interpreter:\s([^\]]+)\]}){

                    $extra .= " interp=$1";

                    # discard line
                    shift @lines;
                }
            }

            $parsed .= "  $header flags=${newflags}$extra\n";

            next;

        } elsif ($line =~ /^\s*\[\s*(\d+)\] (\S+)(?:\s|\Z)/
            && $elf_section eq 'SH') {

            my $section = $2;
            $sections[$1] = $section;

            # We need sections as well (e.g. for incomplete stripping)
            $parsed .= " $section\n"
              if $section =~ /^(?:\.comment$|\.note$|\.z?debug_)/;

        } elsif ($line
            =~ /^\s*0x(?:[0-9A-F]+)\s+\((.*?)\)\s+([\x21-\x7f][\x20-\x7f]*)\Z/i
            && $elf_section eq 'DS') {

            my $type = $1;
            my $value = $2;

            my $keep = 0;

            if ($type eq 'RPATH' or $type eq 'RUNPATH') {
                $value =~ s/^.*\[//;
                $value =~ s/\]\s*$//;
                $keep = 1;

            } elsif ($type eq 'TEXTREL' or $type eq 'DEBUG') {
                $keep = 1;

            } elsif ($type eq 'FLAGS_1') {
                # Will contain "NOW" if the binary was built with -Wl,-z,now
                $value =~ s/^Flags:\s*//i;
                $keep = 1;

            } elsif (($type eq 'FLAGS' and $value =~ m/\bBIND_NOW\b/)
                or $type eq 'BIND_NOW') {

                # Variants of bindnow
                $type = 'FLAGS_1';
                $value = 'NOW';
                $keep = 1;
            }

            $keep = 1
              if $value =~ s/^(?:Shared library|Library soname): \[(.*)\]/$1/;

            $parsed .= "  $type   $value\n"
              if $keep;

        } elsif (
            $line =~ /^\s*[0-9a-f]+: \s* \S+ \s* (?:\(\S+\))? (?:\s|\Z)/xi
            && $elf_section eq 'VS') {

            while ($line =~ /([0-9a-f]+h?)\s*(?:\((\S+)\))?(?:\s|\Z)/gci) {
                my $version_number = $1;
                my $version_string = $2;

                # for libfuse2_2.9.9-3_amd64.deb
                next
                  unless defined $version_string;

                $version_string = "($version_string)"
                  if $version_number =~ /h$/;

                push(@symbol_versions, $version_string);
            }

        } elsif ($line
            =~ /^\s*(\d+):\s*[0-9a-f]+\s+\d+\s+(?:(?:\S+\s+){3})(?:\[.*\]\s+)?(\S+)\s+(.*)\Z/
            && $elf_section eq 'DS') {

           # We (sometimes) need to read the "Version symbols section" first to
           # use this data and readelf tends to print after this section, so
           # save for later.
            push(@dynamic_symbols, [$1, $2, $3]);

        } elsif ($line =~ /^There is no dynamic section in this file/
            && exists $program_headers{DYNAMIC}) {

            # The headers declare a dynamic section but it's
            # empty.
            $parsed .= "Bad-Dynamic-Table: Yes\n";
        }
    }

    $parsed .= "Dynamic-Symbols:\n"
      if @dynamic_symbols;

    for my $dynamic_symbol (@dynamic_symbols) {

        my ($symbol_number, $section, $symbol_name) = @{$dynamic_symbol};
        my $symbol_version;

        if ($symbol_name =~ /^(.*)@(.*) \(.*\)$/) {
            $symbol_name = $1;
            $symbol_version = $2;

        } else {
            $symbol_version = $symbol_versions[$symbol_number] // EMPTY;

            if ($symbol_version eq '*local*' || $symbol_version eq '*global*'){
                if ($section eq 'UND') {
                    $symbol_version = '   ';
                } else {
                    $symbol_version = 'Base';
                }

            } elsif ($symbol_version eq '()') {
                $symbol_version = '(Base)';
            }
        }

        # happens once or twice for regular binaries
        next
          unless length $symbol_name;

        # look up numbered section
        $section = $sections[$section] // $section
          if $section =~ /^\d+$/;

        # We only care about undefined symbols and symbols in
        # the .text segment.
        next
          unless $section eq 'UND' || $section eq '.text';

        $parsed .= " $section $symbol_version $symbol_name\n";
    }

    $parsed .= "\n";

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

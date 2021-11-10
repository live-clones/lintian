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

use Const::Fast;
use Cwd;
use IPC::Run3;
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8 valid_utf8 decode_utf8);

use Lintian::Deb822::File;
use Lintian::Inspect::Elf::Symbol;

use Moo::Role;
use namespace::clean;

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $INDENT => $SPACE x 4;
const my $HYPHEN => q{-};
const my $NEWLINE => qq{\n};

const my $LINES_PER_FILE => 3;

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
    chdir($self->basedir)
      or die encode_utf8('Cannot change to directory ' . $self->basedir);

    my $errors = $EMPTY;

    my @files = grep { $_->is_file } @{$self->sorted_list};

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
        my $combined_bytes;

        run3(\@command, \undef, \$combined_bytes, \$combined_bytes);

        next
          unless length $combined_bytes;

        my $combined_output;

        if (valid_utf8($combined_bytes)) {
            $combined_output = decode_utf8($combined_bytes);

        } else {
            $combined_output = $combined_bytes;
            $errors .= "Output from '@command' is not valid UTF-8" . $NEWLINE;
        }

        # each object file in an archive gets its own File section
        my @per_files = split(/^(File): (.*)$/m, $combined_output);
        shift @per_files while @per_files && $per_files[0] ne 'File';

        @per_files = ($combined_output)
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

        unless (@per_files % $LINES_PER_FILE == 0) {

            $errors
              .= "Parsed data from readelf is not a multiple of $LINES_PER_FILE for $file"
              . $NEWLINE;
            next;
        }

        my $parsed;
        while (defined(my $fixed = shift @per_files)) {

            my $recorded_name = shift @per_files;
            my $per_file = shift @per_files;

            unless ($fixed eq 'File') {
                $errors .= "Unknown output from readelf for $file" . $NEWLINE;
                next;
            }

            unless (length $recorded_name) {
                $errors .= "No file name from readelf for $file" . $NEWLINE;
                next;
            }

            my ($container, $member) = ($recorded_name =~ /^(.*)\(([^)]+)\)$/);

            $container = $recorded_name
              unless defined $container && defined $member;

            unless ($container eq $file->name) {
                $errors
                  .= "Container not same as file name ($container vs $file)"
                  . $NEWLINE;
                next;
            }

            # ignore empty archives, such as in musl-dev_1.2.1-1_amd64.deb
            next
              unless length $per_file;

            $parsed .= parse_per_file($per_file, $recorded_name);
        }

        my $deb822_file = Lintian::Deb822::File->new;
        $deb822_file->parse_string($parsed);

        my %by_file;

        for my $deb822_section (@{$deb822_file->sections}) {

            my %by_object;

            $by_object{ERRORS} = 1
              if lc($deb822_section->value('Broken')) eq 'yes';

            $by_object{'BAD-DYNAMIC-TABLE'} = 1
              if lc($deb822_section->value('Bad-Dynamic-Table')) eq 'yes';

            $by_object{'ELF-TYPE'} = $deb822_section->value('Elf-Type')
              if $deb822_section->declares('Elf-Type');

            my @symbol_definitions
              = $deb822_section->trimmed_list('Dynamic-Symbols', qr{\s*\n\s*});

            for my $definition (@symbol_definitions) {

                if ($definition =~ m/^\s*(\S+)\s+(?:(\S+)\s+)?(\S+)$/){

                    # $version is not always there
                    my $section = $1;
                    my $version = $2;
                    my $name = $3;

                    my $symbol = Lintian::Inspect::Elf::Symbol->new;
                    $symbol->section($section);
                    $symbol->version($version);
                    $symbol->name($name);

                    push(@{ $by_object{SYMBOLS} }, $symbol);
                }
            }

            my @elf_sections
              = $deb822_section->trimmed_list('Section-Headers', qr{\s*\n\s*});

            for my $section (@elf_sections) {

                $by_object{SH}{$section} = 1;
            }

            my @program_headers
              = $deb822_section->trimmed_list('Program-Headers', qr{\s*\n\s*});

            for my $header (@program_headers) {

                my ($type, @kvpairs) = split(/\s+/, $header);

                for my $kvpair (@kvpairs) {

                    my ($key, $value) = split(/=/, $kvpair);

                    if ($type eq 'INTERP' && $key eq 'interp') {
                        $by_object{INTERP} = $value;

                    } else {
                        $by_object{PH}{$type}{$key} = $value;
                    }
                }
            }

            my @dynamic_settings
              = $deb822_section->trimmed_list('Dynamic-Section', qr{\s*\n\s*});

            for my $setting (@dynamic_settings) {

                # Here we just need RPATH and NEEDS, so ignore the rest for now
                my ($type, $remainder) = split(/\s+/, $setting, 2);

                $remainder //= $EMPTY;

                if ($type eq 'RPATH' || $type eq 'RUNPATH') {

                    # RPATH is like PATH
                    my @components = split(/:/, $remainder);

                    $by_object{$type}{$_} = 1 for @components;

                } elsif ($type eq 'NEEDED' || $type eq 'SONAME') {
                    push(@{ $by_object{$type} }, $remainder);

                } elsif ($type eq 'TEXTREL' || $type eq 'DEBUG') {
                    $by_object{$type} = 1;

                } elsif ($type eq 'FLAGS_1') {

                    my @flags = split(/\s+/, $remainder);

                    $by_object{$type}{$_} = 1 for @flags;
                }
            }

            my $file_name;
            my $object_name;

            if ($deb822_section->value('Filename') =~ m{^(.+)\(([^/\)]+)\)$}) {

                # object file in a static lib.
                $file_name = $1;
                $object_name = $2;
            }

            $file_name //= $deb822_section->value('Filename');
            $object_name //= $EMPTY;

            $by_file{$object_name} = \%by_object;
        }

        $file->objdump(\%by_file);
    }

    chdir($savedir)
      or die encode_utf8("Cannot change to directory $savedir");

    return $errors;
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
    my $elf_section = $EMPTY;
    my $static_lib_issues = 0;

    my $parsed = "Filename: $filename" . $NEWLINE;

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
            $parsed .= 'Broken: yes' . $NEWLINE
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
            $parsed .= "Elf-Type: $1" . $NEWLINE;
            next;

        } elsif ($line =~ /^Program Headers:/) {
            $elf_section = 'PH';
            $parsed .= 'Program-Headers:' . $NEWLINE;

        } elsif ($line =~ /^Section Headers:/) {
            $elf_section = 'SH';
            $parsed .= 'Section-Headers:' . $NEWLINE;

        } elsif ($line =~ /^Dynamic section at offset .*:/) {
            $elf_section = 'DS';
            $parsed .= 'Dynamic-Section:' . $NEWLINE;

        } elsif ($line =~ /^Version symbols section /) {
            $elf_section = 'VS';

        } elsif ($line =~ /^Symbol table '.dynsym'/) {
            $elf_section = 'DS';

        } elsif ($line =~ /^Symbol table/) {
            $elf_section = $EMPTY;

        } elsif ($line =~ /^\s*$/) {
            $elf_section = $EMPTY;

        } elsif ($line =~ /^\s*(\S+)\s*(?:(?:\S+\s+){4})\S+\s(...)/
            and $elf_section eq 'PH') {

            my $header = $1;
            my $flags = $2;

            $header =~ s/^GNU_//g;

            next
              if $header eq 'Type';

            my $extra = $EMPTY;

            my $newflags = $EMPTY;
            $newflags .= ($flags =~ /R/) ? 'r' : $HYPHEN;
            $newflags .= ($flags =~ /W/) ? 'w' : $HYPHEN;
            $newflags .= ($flags =~ /E/) ? 'x' : $HYPHEN;

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

            $parsed .= "  $header flags=${newflags}$extra" . $NEWLINE;

            next;

        } elsif ($line =~ /^\s*\[\s*(\d+)\] (\S+)(?:\s|\Z)/
            && $elf_section eq 'SH') {

            my $section = $2;
            $sections[$1] = $section;

            # We need sections as well (e.g. for incomplete stripping)
            $parsed .= $SPACE . $section . $NEWLINE
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

            $parsed .= "  $type   $value" . $NEWLINE
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
            $parsed .= 'Bad-Dynamic-Table: Yes' . $NEWLINE;
        }
    }

    $parsed .= 'Dynamic-Symbols:' . $NEWLINE
      if @dynamic_symbols;

    for my $dynamic_symbol (@dynamic_symbols) {

        my ($symbol_number, $section, $symbol_name) = @{$dynamic_symbol};
        my $symbol_version;

        if ($symbol_name =~ /^(.*)@(.*) \(.*\)$/) {
            $symbol_name = $1;
            $symbol_version = $2;

        } else {
            $symbol_version = $symbol_versions[$symbol_number] // $EMPTY;

            if ($symbol_version eq '*local*' || $symbol_version eq '*global*'){
                if ($section eq 'UND') {
                    $symbol_version = $INDENT;
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

        $parsed .= " $section $symbol_version $symbol_name" . $NEWLINE;
    }

    $parsed .= $NEWLINE;

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

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
use Unicode::UTF8 qw(encode_utf8 valid_utf8 decode_utf8);

use Lintian::Inspect::Elf::Symbol;

use Moo::Role;
use namespace::clean;

const my $EMPTY => q{};
const my $SPACE => q{ };
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

        my @command = (qw{readelf --all --wide}, $file->name);
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

            my $object_name;
            if ($recorded_name =~ m{^(?:.+)\(([^/\)]+)\)$}){

                # object file in a static lib.
                $object_name = $1;
            }

            parse_per_file($file, $object_name, $per_file);
        }
    }

    chdir($savedir)
      or die encode_utf8("Cannot change to directory $savedir");

    return $errors;
}

=item parse_per_file

=cut

sub parse_per_file {
    my ($file, $object_name, $from_readelf) = @_;

    my %by_object;

    if (length $object_name) {

        # object file in a static lib.
        $file->elf_by_member->{$object_name} = \%by_object;

    } else {
        $file->elf(\%by_object);
    }

    $by_object{READELF} = $from_readelf;

    my @paragraphs = split(m{\n\n}, $from_readelf);
    for my $paragraph (@paragraphs) {

        my ($first, $bulk) = split(m{\n}, $paragraph, 2);

        if ($first =~ /^ELF Header:/) {
            elf_header($bulk, \%by_object);
            next;
        }

        if ($first =~ /^Program Headers:/) {
            program_headers($bulk, \%by_object);
            next;
        }

        if ($first =~ /^Dynamic section at offset .*:/) {
            dynamic_section($bulk, \%by_object);
            next;
        }

        if ($first =~ /^Section Headers:/) {
            section_headers($bulk, \%by_object);
            next;
        }

        if ($first =~ /^Symbol table '.dynsym'/) {
            symbol_table($bulk, \%by_object);
            next;
        }

        if ($first =~ /^Version symbols section /) {
            version_symbols($bulk, \%by_object);
            next;
        }

        if ($first =~ /^There is no dynamic section in this file/) {
            # a dynamic section was declared but it's empty.
            $by_object{'BAD-DYNAMIC-TABLE'} = 1
              if exists $by_object{PH}{DYNAMIC};
            next;
        }
    }

    my %section_name_by_number;
    for my $name (keys %{$by_object{SH} // {}}) {

        my $number = $by_object{SH}{$name}{number};
        $section_name_by_number{$number} = $name;
    }

    for my $symbol_number (keys %{$by_object{'DYNAMIC-SYMBOLS'}}) {

        my $symbol_name
          = $by_object{'DYNAMIC-SYMBOLS'}{$symbol_number}{symbol_name};
        my $section_number
          = $by_object{'DYNAMIC-SYMBOLS'}{$symbol_number}{section_number};

        my $symbol_version;

        if ($symbol_name =~ m{^ (.*) @ (.*) \s [(] .* [)] $}x) {

            $symbol_name = $1;
            $symbol_version = $2;

        } else {
            $symbol_version = $by_object{'SYMBOL-VERSIONS'}{$symbol_number}
              // $EMPTY;

            if (   $symbol_version eq '*local*'
                || $symbol_version eq '*global*'){

                if ($section_number eq 'UND') {
                    $symbol_version = $EMPTY;

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
        my $section_name = $section_name_by_number{$section_number}
          // $section_number;

        my $symbol = Lintian::Inspect::Elf::Symbol->new;
        $symbol->section($section_name);
        $symbol->version($symbol_version);
        $symbol->name($symbol_name);

        push(@{ $by_object{SYMBOLS} }, $symbol);
    }

    return;
}

=item elf_header

=cut

sub elf_header {
    my ($text, $by_object) = @_;

    my @lines = split(m{\n}, $text);

    for my $line (@lines) {

        if ($line =~ m{^ readelf: \s+ Error: \s+ (.*)}x) {

            my $error = $1;

            $by_object->{ERRORS} //= [];
            push(@{$by_object->{ERRORS}}, $error);

            next;
        }

        my ($field, $value) = split(/:/, $line, 2);

        # trim both ends
        $field =~ s/^\s+|\s+$//g;
        $value =~ s/^\s+|\s+$//g;

        next
          unless length $field && length $value;

        $by_object->{'ELF-HEADER'}{$field} = $value;
    }

    return;
}

=item program_headers

=cut

sub program_headers {
    my ($text, $by_object) = @_;

    my @lines = split(m{\n}, $text);

    while (defined(my $line = shift @lines)) {

        if ($line =~ m{^ \s* (\S+) \s* (?:(?:\S+\s+){4}) \S+ \s (...) }x) {

            my $header = $1;
            my $flags = $2;

            $header =~ s/^GNU_//g;

            next
              if $header eq 'Type';

            my $newflags = $EMPTY;
            $newflags .= ($flags =~ /R/) ? 'r' : $HYPHEN;
            $newflags .= ($flags =~ /W/) ? 'w' : $HYPHEN;
            $newflags .= ($flags =~ /E/) ? 'x' : $HYPHEN;

            $by_object->{PH}{$header}{flags} = $newflags;

            if ($header eq 'INTERP' && @lines) {
                # Check if the next line is the "requesting an interpreter"
                # (readelf appears to always emit on the next line if at all)
                my $next_line = $lines[0];

                if ($next_line
                    =~ m{ [[] Requesting \s program \s interpreter: \s ([^\]]+) []] }x
                ){

                    my $interpreter = $1;

                    $by_object->{INTERP} = $interpreter;

                    # discard line
                    shift @lines;
                }
            }
        }
    }

    return;
}

=item dynamic_section

=cut

sub dynamic_section {
    my ($text, $by_object) = @_;

    my @lines = split(m{\n}, $text);

    while (defined(my $line = shift @lines)) {

        if ($line
            =~ m{^ \s* 0x (?:[0-9A-F]+) \s+ [(] (.*?) [)] \s+ ([\x21-\x7f][\x20-\x7f]*) \Z}ix
        ) {

            my $type = $1;
            my $remainder = $2;

            my $keep = 0;

            if ($type eq 'RPATH' || $type eq 'RUNPATH') {
                $remainder =~ s{^ .* [[] }{}x;
                $remainder =~ s{ []] \s* $}{}x;
                $keep = 1;

            } elsif ($type eq 'TEXTREL' || $type eq 'DEBUG') {
                $keep = 1;

            } elsif ($type eq 'FLAGS_1') {
                # Will contain "NOW" if the binary was built with -Wl,-z,now
                $remainder =~ s/^Flags:\s*//i;
                $keep = 1;

            } elsif (($type eq 'FLAGS' && $remainder =~ m/\bBIND_NOW\b/)
                || $type eq 'BIND_NOW') {

                # Variants of bindnow
                $type = 'FLAGS_1';
                $remainder = 'NOW';
                $keep = 1;
            }

            $keep = 1
              if $remainder
              =~ s{^ (?: Shared \s library | Library \s soname ) : \s [[] (.*) []] }{$1}x;

            next
              unless $keep;

            # Here we just need RPATH and NEEDS, so ignore the rest for now
            if ($type eq 'RPATH' || $type eq 'RUNPATH') {

                # RPATH is like PATH
                my @components = split(/:/, $remainder);
                $by_object->{$type}{$_} = 1 for @components;

            } elsif ($type eq 'NEEDED' || $type eq 'SONAME') {
                push(@{ $by_object->{$type} }, $remainder);

            } elsif ($type eq 'TEXTREL' || $type eq 'DEBUG') {
                $by_object->{$type} = 1;

            } elsif ($type eq 'FLAGS_1') {

                my @flags = split(/\s+/, $remainder);
                $by_object->{$type}{$_} = 1 for @flags;
            }
        }
    }

    return;
}

=item section_headers

=cut

sub section_headers {
    my ($text, $by_object) = @_;

    my @lines = split(m{\n}, $text);

    while (defined(my $line = shift @lines)) {

        if ($line =~ m{^ \s* [[] \s* (\d+) []] \s+ (\S+) (?:\s | \Z) }x) {

            my $number = $1;
            my $name = $2;

            $by_object->{SH}{$name}{number} = $number;
        }
    }

    return;
}

=item symbol_table

=cut

sub symbol_table {
    my ($text, $by_object) = @_;

    # We (sometimes) need to read the "Version symbols section" first to
    # use this data and readelf tends to print after this section, so
    # save for later.

    my @lines = split(m{\n}, $text);

    while (defined(my $line = shift @lines)) {

        if ($line
            =~ m{^ \s* (\d+) : \s* [0-9a-f]+ \s+ \d+ \s+ (?:(?:\S+\s+){3}) (?: [[] .* []] \s+)? (\S+) \s+ (.*) \Z}x
        ) {

            my $symbol_number = $1;
            my $section_number = $2;
            my $symbol_name = $3;

            $by_object->{'DYNAMIC-SYMBOLS'}{$symbol_number}{section_number}
              = $section_number;
            $by_object->{'DYNAMIC-SYMBOLS'}{$symbol_number}{symbol_name}
              = $symbol_name;
        }
    }

    return;
}

=item version_symbols

=cut

sub version_symbols {
    my ($text, $by_object) = @_;

    my @lines = split(m{\n}, $text);

    while (defined(my $line = shift @lines)) {

        if ($line
            =~ m{^ \s* [0-9a-f]+ : \s* \S+ \s* (?: [(] \S+ [)] )? (?: \s | \Z ) }xi
        ){

            while ($line
                =~ m{ ([0-9a-f]+ h?) \s* (?: [(] (\S+) [)] )? (?: \s | \Z ) }cgix
            ) {

                my $symbol_number = $1;
                my $symbol_version = $2;

                # for libfuse2_2.9.9-3_amd64.deb
                next
                  unless length $symbol_version;

                $symbol_version = "($symbol_version)"
                  if $symbol_number =~ m{ h $}x;

                $by_object->{'SYMBOL-VERSIONS'}{$symbol_number}
                  = $symbol_version;
            }
        }
    }

    return;
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

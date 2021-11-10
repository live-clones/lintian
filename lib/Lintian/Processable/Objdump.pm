# -*- perl -*- Lintian::Processable::Objdump
#
# Copyright © 2019-2021 Felix Lechner
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

package Lintian::Processable::Objdump;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(uniq);

use Lintian::Deb822::File;
use Lintian::Inspect::Elf::Symbol;

use Moo::Role;
use namespace::clean;

const my $EMPTY => q{};
const my $NEWLINE => qq{\n};

=head1 NAME

Lintian::Processable::Objdump - access to collected binary object data

=head1 SYNOPSIS

    use Lintian::Processable;

=head1 DESCRIPTION

Lintian::Processable::Objdump provides an interface to collected binary object data.

=head1 INSTANCE METHODS

=over 4

=item objdump_info

Returns a hashref mapping a FILE to the data collected by objdump-info
or C<undef> if no data is available for that FILE.  Data is generally
only collected for ELF files.

=cut

has objdump_info => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my @objdump = map { $_->objdump } @{$self->installed->sorted_list};
        my $concatenated = join($NEWLINE, @objdump);

        my $deb822_file = Lintian::Deb822::File->new;
        $deb822_file->parse_string($concatenated);

        my %objdump_info;

        for my $deb822_section (@{$deb822_file->sections}) {

            my %info;

            $info{ERRORS} = 1
              if lc($deb822_section->value('Broken')) eq 'yes';

            $info{'BAD-DYNAMIC-TABLE'} = 1
              if lc($deb822_section->value('Bad-Dynamic-Table')) eq 'yes';

            $info{'ELF-TYPE'} = $deb822_section->value('Elf-Type')
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

                    push(@{ $info{SYMBOLS} }, $symbol);
                }
            }

            my @elf_sections
              = $deb822_section->trimmed_list('Section-Headers', qr{\s*\n\s*});

            for my $section (@elf_sections) {

                $info{SH}{$section} = 1;
            }

            my @program_headers
              = $deb822_section->trimmed_list('Program-Headers', qr{\s*\n\s*});

            for my $header (@program_headers) {

                my ($type, @kvpairs) = split(/\s+/, $header);

                for my $kvpair (@kvpairs) {

                    my ($key, $value) = split(/=/, $kvpair);

                    if ($type eq 'INTERP' && $key eq 'interp') {
                        $info{INTERP} = $value;

                    } else {
                        $info{PH}{$type}{$key} = $value;
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

                    $info{$type}{$_} = 1 for @components;

                } elsif ($type eq 'NEEDED' || $type eq 'SONAME') {
                    push(@{ $info{$type} }, $remainder);

                } elsif ($type eq 'TEXTREL' || $type eq 'DEBUG') {
                    $info{$type} = 1;

                } elsif ($type eq 'FLAGS_1') {

                    my @flags = split(/\s+/, $remainder);

                    $info{$type}{$_} = 1 for @flags;
                }
            }

            if ($deb822_section->value('Filename') =~ m{^(.+)\(([^/\)]+)\)$}) {

                # object file in a static lib.
                my $archive = $1;
                my $object = $2;

                $objdump_info{$archive} //= {
                    'filename' => $archive,
                    'objects'  => [],
                };

                push(@{ $objdump_info{$archive}->{objects} }, $object);
            }

            $objdump_info{$deb822_section->value('Filename')} = \%info;
        }

        # make object lists unique
        $objdump_info{$_}->{objects}= [uniq @{ $objdump_info{$_}->{objects} }]
          for keys %objdump_info;

        return \%objdump_info;
    });

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

# -*- perl -*- Lintian::Processable::Objdump
#
# Copyright © 2019 Felix Lechner
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
use autodie;

use Path::Tiny;

use Lintian::Deb822Parser qw(parse_dpkg_control_string);

use constant EMPTY => q{};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Objdump - access to collected binary object data

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Processable::Objdump provides an interface to collected binary object data.

=head1 INSTANCE METHODS

=over 4

=item objdump_info

Returns a hashref mapping a FILE to the data collected by objdump-info
or C<undef> if no data is available for that FILE.  Data is generally
only collected for ELF files.

Needs-Info requirements for using I<objdump_info>: objdump-info

=cut

sub objdump_info {
    my ($self) = @_;

    return $self->{objdump_info}
      if exists $self->{objdump_info};

    my @objdump = map { $_->objdump } $self->installed->sorted_list;
    my $concatenated = join(EMPTY, @objdump);

    my @paragraphs = parse_dpkg_control_string($concatenated);

    my %objdump_info;
    local $_;

    for my $paragraph (@paragraphs) {

        my %info;

        $info{'ERRORS'} = 1
          if lc($paragraph->{'Broken'}//'no') eq 'yes';

        $info{'BAD-DYNAMIC-TABLE'} = 1
          if lc($paragraph->{'Bad-Dynamic-Table'}//'no') eq 'yes';

        $info{'ELF-TYPE'} = $paragraph->{'Elf-Type'}
          if defined $paragraph->{'Elf-Type'};

        for
          my $symd (split m/\s*\n\s*/, $paragraph->{'Dynamic-Symbols'}//EMPTY){
            next
              unless length $symd;

            if ($symd =~ m/^\s*(\S+)\s+(?:(\S+)\s+)?(\S+)$/){
                # $ver is not always there
                my ($sec, $ver, $sym) = ($1, $2, $3);
                $ver //= EMPTY;
                push @{ $info{'SYMBOLS'} }, [$sec, $ver, $sym];
            }
        }

        for my $section (split m/\s*\n\s*/,
            $paragraph->{'Section-Headers'}//EMPTY){
            next
              unless length $section;
            # NB: helpers/coll/objdump-info-helper discards most
            # sections.  If you are missing a section name for a
            # check, please update helpers/coll/objdump-info-helper to
            # retrain the section name you need.

            # trim both ends
            $section =~ s/^\s+|\s+$//g;

            $info{'SH'}{$section} = 1;
        }

        for
          my $data (split m/\s*\n\s*/, $paragraph->{'Program-Headers'}//EMPTY){
            next
              unless length $data;

            my ($header, @vals) = split m/\s++/, $data;

            for my $extra (@vals) {

                my ($opt, $val) = split m/=/, $extra;
                if ($opt eq 'interp' and $header eq 'INTERP') {
                    $info{'INTERP'} = $val;

                } else {
                    $info{'PH'}{$header}{$opt} = $val;
                }
            }
        }

        for
          my $data (split m/\s*\n\s*/, $paragraph->{'Dynamic-Section'}//EMPTY){
            next
              unless length $data;

            # Here we just need RPATH and NEEDS, so ignore the rest for now
            my ($header, $val) = split(m/\s++/, $data, 2);
            if ($header eq 'RPATH' or $header eq 'RUNPATH') {
                # RPATH is like PATH
                for my $rpathcomponent (split(/:/, $val // EMPTY)) {
                    $info{$header}{$rpathcomponent} = 1;
                }

            } elsif ($header eq 'NEEDED' or $header eq 'SONAME') {
                push @{ $info{$header} }, $val;

            } elsif ($header eq 'TEXTREL' or $header eq 'DEBUG') {
                $info{$header} = 1;

            } elsif ($header eq 'FLAGS_1') {
                for my $flag (split(m/\s++/, $val)) {
                    $info{$header}{$flag} = 1;
                }
            }
        }

        if ($paragraph->{'Filename'} =~ m,^(.+)\(([^/\)]+)\)$,) {

            # object file in a static lib.
            my ($lib, $obj) = ($1, $2);
            my $libentry = $objdump_info{$lib};
            if (not defined $libentry) {
                $libentry = {
                    'filename' => $lib,
                    'objects'  => [$obj],
                };
                $objdump_info{$lib} = $libentry;

            } else {
                push @{ $libentry->{'objects'} }, $obj;
            }
        }

        $objdump_info{$paragraph->{'Filename'}} = \%info;
    }

    $self->{objdump_info} = \%objdump_info;

    return $self->{objdump_info};
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

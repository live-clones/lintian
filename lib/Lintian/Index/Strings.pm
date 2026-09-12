# -*- perl -*- Lintian::Index::Strings
#
# Copyright (C) 2020 Felix Lechner
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

package Lintian::Index::Strings;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Path::Tiny;
use Unicode::UTF8 qw(decode_utf8);

use Lintian::IPC::Run3 qw(xargs);

use Moo::Role;
use namespace::clean;

const my $EMPTY => q{};

=head1 NAME

Lintian::Index::Strings - strings in binary files.

=head1 SYNOPSIS

    use Lintian::Index;

=head1 DESCRIPTION

Lintian::Index::Strings strings in binary files.

=head1 INSTANCE METHODS

=over 4

=item add_strings

=cut

sub add_strings {
    my ($self) = @_;

    my $errors = $EMPTY;

    my @files = grep { $_->is_file } @{$self->sorted_list};

    # collect ELF files outside debug directories
    my %by_path;
    for my $file (@files) {

        next
          if $file->name =~ m{^usr/lib/debug/};

        # skip non-binaries
        next
          unless $file->file_type =~ /\bELF\b/;

        $by_path{$file->unpacked_path} = $file;
    }

    my @paths = keys %by_path;
    return $errors
      unless @paths;

    # one strings(1) invocation per xargs batch instead of one per file;
    # GNU strings prefixes each line with "FILE: " via --print-file-name
    my $processor = sub {
        my ($stdout) = @_;

        my %strings;
        for my $line (split /\n/, $stdout) {

            next
              if $line eq $EMPTY;

            my ($path, $string) = split /: /, $line, 2;

            next
              unless defined $string && exists $by_path{$path};

            push @{$strings{$path}}, $string;
        }

        for my $path (keys %strings) {
            my $file = $by_path{$path};
            $file->strings(
                decode_utf8(join qq{\n}, @{$strings{$path}}, $EMPTY));
        }

        return;
    };

    xargs([qw{strings --all -f --}], \@paths, $processor);

    return $errors;
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

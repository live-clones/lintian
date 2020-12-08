# Copyright © 2020 Felix Lechner
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

package Lintian::Deb822::File;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Deb822::Parser qw(parse_dpkg_control_string);
use Lintian::Deb822::Section;

const my $EMPTY => q{};

use Moo;
use namespace::clean;

=encoding utf-8

=head1 NAME

Lintian::Deb822::File -- A deb822 control file

=head1 SYNOPSIS

 use Lintian::Deb822::File;

=head1 DESCRIPTION

Represents a paragraph in a Deb822 control file.

=head1 INSTANCE METHODS

=over 4

=item sections

Array of Deb822::Section objects in order of their original appearance.

=item positions

Line positions

=cut

has sections => (is => 'rw', default => sub { [] });
has positions => (is => 'rw', default => sub { [] });

=item first_mention

=cut

sub first_mention {
    my ($self, $name) = @_;

    my $earliest;

    # empty when field not present
    $earliest ||= $_->value($name) for @{$self->sections};

    return ($earliest // $EMPTY);
}

=item last_mention

=cut

sub last_mention {
    my ($self, $name) = @_;

    my $latest;

    for my $section (@{$self->sections}) {

        # empty when field not present
        $latest = $section->value($name)
          if $section->declares($name);
    }

    return ($latest // $EMPTY);
}

=item read_file

=cut

sub read_file {
    my ($self, $path, $flags) = @_;

    my $contents = path($path)->slurp_utf8;

    return $self->parse_string($contents, $flags);
}

=item parse_string

=cut

sub parse_string {
    my ($self, $contents, $flags) = @_;

    my (@paragraphs, @positions);

    eval {
        @paragraphs= parse_dpkg_control_string($contents, $flags,\@positions);
    };

    if (length $@) {
        chomp $@;
        $@ =~ s/^syntax error at //;
        die encode_utf8("syntax error in $@\n")
          if length $@;
    }

    my $index = 0;
    for my $paragraph (@paragraphs) {

        my $section = Lintian::Deb822::Section->new;
        $section->verbatim($paragraph);
        $section->positions($positions[$index]);

        push(@{$self->sections}, $section);

    } continue {
        $index++;
    }

    return @{$self->sections};
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

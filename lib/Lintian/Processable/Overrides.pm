# -*- perl -*- Lintian::Processable::Overrides
#
# Copyright (C) 2019-2021 Felix Lechner
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

package Lintian::Processable::Overrides;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

use Lintian::Override;

const my $EMPTY => q{};
const my $SPACE => q{ };

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Overrides - access to override data

=head1 SYNOPSIS

    use Lintian::Processable;

=head1 DESCRIPTION

Lintian::Processable::Overrides provides an interface to overrides.

=head1 INSTANCE METHODS

=over 4

=item override_errors

=cut

has override_errors => (is => 'rw', default => sub { [] });

=item parse_overrides

=cut

sub parse_overrides {
    my ($self, $contents) = @_;

    $contents //= $EMPTY;

    my @declared_overrides;

    my $justification = $EMPTY;
    my $previous = Lintian::Override->new;

    my @lines = split(/\n/, $contents);

    my $position = 1;
    for my $line (@lines) {

        my $remaining = $line;

        # trim both ends
        $remaining =~ s/^\s+|\s+$//g;

        if ($remaining eq $EMPTY) {
            # Throw away comments, as they are not attached to a tag
            # also throw away the option of "carrying over" the last
            # comment
            $justification = $EMPTY;
            $previous = Lintian::Override->new;
            next;
        }

        if ($remaining =~ s{^ [#] \s* }{}x) {

            if (length $remaining) {

                $justification .= $SPACE
                  if length $justification;

                $justification .= $remaining;
            }

            next;
        }

        # reduce white space
        $remaining =~ s/\s+/ /g;

        # [[pkg-name] [arch-list] [pkg-type]:] <tag> [context]
        my $require_colon = 0;
        my @architectures;

        # strip package name, if present; require name
        # parsing overrides is ambiguous (see #699628)
        my $package = $self->name;
        if ($remaining =~ s/^\Q$package\E(?=\s|:)//) {

            # both spaces or colon were unmatched lookhead
            $remaining =~ s/^\s+//;
            $require_colon = 1;
        }

        # remove architecture list
        if ($remaining =~ s{^ \[ ([^\]]*) \] (?=\s|:)}{}x) {

            my $list = $1;

            @architectures = split($SPACE, $list);

            # both spaces or colon were unmatched lookhead
            $remaining =~ s/^\s+//;
            $require_colon = 1;
        }

        # remove package type
        my $type = $self->type;
        if ($remaining =~ s/^\Q$type\E(?=\s|:)//) {

            # both spaces or colon were unmatched lookhead
            $remaining =~ s/^\s+//;
            $require_colon = 1;
        }

        my $pointer = $self->override_file->pointer($position);

        # require and remove colon when any package details are present
        if ($require_colon && $remaining !~ s/^\s*:\s*//) {

            my %error;
            $error{message} = 'Expected a colon';
            $error{pointer} = $pointer;
            push(@{$self->override_errors}, \%error);

            next;
        }

        my $hint_like = $remaining;

        my ($tag_name, $pattern) = split($SPACE, $hint_like, 2);

        if (!length $tag_name) {

            my %error;
            $error{message} = "Cannot parse line: $line";
            $error{pointer} = $pointer;
            push(@{$self->override_errors}, \%error);

            next;
        }

        $pattern //= $EMPTY;

        # There are no new comments, no "empty line" in between and
        # this tag is the same as the last, so we "carry over" the
        # comment from the previous override (if any).
        $justification = $previous->justification
          if !length $justification
          && $tag_name eq $previous->tag_name;

        my $current = Lintian::Override->new;

        $current->tag_name($tag_name);
        $current->architectures(\@architectures);
        $current->pattern($pattern);
        $current->position($position);

        # combine successive white space
        $justification =~ s{ \s+ }{ }gx;

        $current->justification($justification);
        $justification = $EMPTY;

        push(@declared_overrides, $current);

        $previous = $current;

    } continue {
        $position++;
    }

    return \@declared_overrides;
}

1;

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1)

=cut

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

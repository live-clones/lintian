# -*- perl -*- Lintian::Processable::Overrides
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

package Lintian::Processable::Overrides;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(none true);

use Lintian::Pointer::Item;

use Moo::Role;
use namespace::clean;

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $ASTERISK => q{*};
const my $DOT => q{.};

=head1 NAME

Lintian::Processable::Overrides - access to override data

=head1 SYNOPSIS

    use Lintian::Processable;

=head1 DESCRIPTION

Lintian::Processable::Overrides provides an interface to overrides.

=head1 INSTANCE METHODS

=over 4

=item parse_overrides

=cut

sub parse_overrides {
    my ($self, $contents) = @_;

    $contents //= $EMPTY;

    my %override_data;

    my @comments;
    my %previous;

    my @lines = split(/\n/, $contents);

    my $position = 1;
    for my $line (@lines) {

        my $pointer = Lintian::Pointer::Item->new;
        $pointer->item($self->override_file);
        $pointer->position($position);

        my $remaining = $line;

        # trim both ends
        $remaining =~ s/^\s+|\s+$//g;

        if ($remaining eq $EMPTY) {
            # Throw away comments, as they are not attached to a tag
            # also throw away the option of "carrying over" the last
            # comment
            @comments = ();
            %previous = ();
            next;
        }

        if ($remaining =~ /^#/) {
            $remaining =~ s/^# ?//;
            push(@comments, $remaining);
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
        if ($remaining =~ s/^\[([^\]]*)\](?=\s|:)//) {
            @architectures = split($SPACE, $1);

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

        # require and remove colon when any package details are present
        if ($require_colon && $remaining !~ s/^\s*:\s*//) {
            $self->pointed_hint('malformed-override', $pointer,
                'Expected a colon');
            next;
        }

        my $hint = $remaining;

        if (@architectures && $self->architecture eq 'all') {
            $self->pointed_hint('malformed-override', $pointer,
                'Architecture list for arch:all package');
            next;
        }

        my @invalid
          = grep { !$self->profile->architectures->valid_restriction($_) }
          @architectures;
        $self->pointed_hint('malformed-override', $pointer,
            "Unknown architecture wildcard $_")
          for @invalid;

        next
          if @invalid;

        # count negations
        my $negations = true { /^!/ } @architectures;

        # confirm it is either all or none
        unless ($negations == @architectures || $negations == 0) {
            $self->pointed_hint('malformed-override', $pointer,
                'Inconsistent architecture negation');
            next;
        }

        # strip negations if present
        s/^!// for @architectures;

        # proceed when none specified
        next
          if @architectures
          && (
            $negations xor none {
                $self->profile->architectures->restriction_matches($_,
                    $self->architecture)
            }
            @architectures
          );

        my ($tagname, $context) = split($SPACE, $hint, 2);

        $self->pointed_hint('malformed-override', $pointer,
            "Cannot parse line: $line")
          unless length $tagname;

        $context //= $EMPTY;

        if (($previous{tag} // $EMPTY) eq $tagname
            && !scalar @comments){
            # There are no new comments, no "empty line" in between and
            # this tag is the same as the last, so we "carry over" the
            # comment from the previous override (if any).
            #
            # Since L::T::Override is (supposed to be) immutable, the new
            # override can share the reference with the previous one.
            push(@comments, @{$previous{comments}});
        }

        my %current;
        $current{tag} = $tagname;

        # record line number
        $current{line} = $position;

        $current{context} = $context;

        if ($context =~ m/\*/) {
            # It is a pattern, pre-compute it
            my $pattern = $context;
            my $end = $EMPTY; # Trailing "match anything" (if any)
            my $pat = $EMPTY; # The rest of the pattern
             # Split does not help us if $pattern ends with *
             # so we deal with that now
            if ($pattern =~ s/\Q*\E+\z//){
                $end = $DOT . $ASTERISK;
            }

            # Are there any * left (after the above)?
            if ($pattern =~ m/\Q*\E/) {
                # this works even if $text starts with a *, since
                # that is split as $EMPTY, <text>
                my @pargs = split(m/\Q*\E++/, $pattern);
                $pat = join($DOT . $ASTERISK, map { quotemeta } @pargs);
            } else {
                $pat = $pattern;
            }

            $current{pattern} = qr/$pat$end/;
        }

        $current{comments} = [];
        push(@{$current{comments}}, @comments);
        @comments = ();

        $override_data{$tagname} //= {};

        if (exists $override_data{$tagname}{$context}) {

            my @same_context
              = ($override_data{$tagname}{$context}{line}, $current{line});

            my $lines = join($SPACE, sort @same_context);

            $self->pointed_hint('duplicate-override-context', $pointer,
                $tagname, "(lines $lines)");

            next;
        }

        $override_data{$tagname}{$context} = \%current;

        %previous = %current;

    } continue {
        $position++;
    }

    return \%override_data;
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

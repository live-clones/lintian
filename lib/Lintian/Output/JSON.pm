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

package Lintian::Output::JSON;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Time::Piece;
use JSON::MaybeXS;

use Moo;
use namespace::clean;

const my $EMPTY => q{};

const my %CODE_PRIORITY => (
    'E' => 30,
    'W' => 40,
    'I' => 50,
    'P' => 60,
    'X' => 70,
    'C' => 80,
    'O' => 90,
);

=head1 NAME

Lintian::Output::JSON - JSON hint output

=head1 SYNOPSIS

    use Lintian::Output::JSON;

=head1 DESCRIPTION

Provides JSON hint output.

=head1 INSTANCE METHODS

=over 4

=item issue_hints

Print all hints passed in array. A separate arguments with processables
is necessary to report in case no hints were found.

=cut

sub issue_hints {
    my ($self, $groups) = @_;

    $groups //= [];

    my %output;

    $output{'lintian-version'} = $ENV{LINTIAN_VERSION};

    my @allgroups_output;
    $output{groups} = \@allgroups_output;

    for my $group (sort { $a->name cmp $b->name } @{$groups}) {

        my %group_output;
        $group_output{'group-id'} = $group->name;

        push(@allgroups_output, \%group_output);

        my @allfiles_output;
        $group_output{'input-files'} = \@allfiles_output;

        for my $processable (sort {$a->path cmp $b->path}
            $group->get_processables) {

            my %file_output;
            $file_output{path} = $processable->path;
            $file_output{hints} = $self->hintlist($processable->hints);

            push(@allfiles_output, \%file_output);
        }
    }

    # convert to UTF-8 prior to encoding in JSON
    my $encoder = JSON->new;
    $encoder->canonical;
    $encoder->utf8;
    $encoder->pretty;

    my $json = $encoder->encode(\%output);

    # output encoded JSON; is already in UTF-8
    print $json;

    return;
}

=item C<hintlist>

=cut

sub hintlist {
    my ($self, $arrayref) = @_;

    my @hints;

    my @sorted = sort {
               defined $a->override <=> defined $b->override
          ||   $CODE_PRIORITY{$a->tag->code}<=> $CODE_PRIORITY{$b->tag->code}
          || $a->tag->name cmp $b->tag->name
          || $a->context cmp $b->context
    } @{$arrayref // []};

    for my $input (@sorted) {

        my %hint;
        push(@hints, \%hint);

        $hint{tag} = $input->tag->name;

        $hint{context} = $input->context
          if length $input->context;

        $hint{visibility} = $input->tag->effective_severity;
        $hint{experimental} = 'yes'
          if $input->tag->experimental;

        if ($input->override) {

            $hint{override} = 'yes';

            my @comments = @{ $input->override->{comments} // [] };
            $hint{'override-comments'} = \@comments
              if @comments;
        }
    }

    return \@hints;
}

=item describe_tags

=cut

sub describe_tags {
    my ($self, @tags) = @_;

    my @array;

    for my $tag (@tags) {

        my %dictionary;

        $dictionary{Name} = $tag->name;
        $dictionary{'Name-Spaced'} = $tag->name_spaced
          if length $tag->name_spaced;
        $dictionary{'Show-Always'} = $tag->show_always
          if length $tag->show_always;

        $dictionary{Explanation} = $tag->explanation;
        $dictionary{'See-Also'} = $tag->see_also
          if @{$tag->see_also};

        $dictionary{Check} = $tag->check;
        $dictionary{Visibility} = $tag->visibility;
        $dictionary{Experimental} = $tag->experimental
          if length $tag->experimental;

        $dictionary{'Renamed-From'} = $tag->renamed_from
          if @{$tag->renamed_from};

        push(@array, \%dictionary);
    }

    # convert to UTF-8 prior to encoding in JSON
    my $encoder = JSON->new;
    $encoder->canonical;
    $encoder->utf8;
    $encoder->pretty;

    # encode single tags without array bracketing
    my $object = \@array;
    $object = $array[0]
      if scalar @array == 1;

    my $json = $encoder->encode($object);

    # output encoded JSON; is already in UTF-8
    print $json;

    return;
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

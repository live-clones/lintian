# Copyright (C) 2020-2021 Felix Lechner
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

use Lintian::Output::Markdown qw(markdown_citation);

const my $EMPTY => q{};

const my %CODE_PRIORITY => (
    'E' => 30,
    'W' => 40,
    'I' => 50,
    'P' => 60,
    'X' => 70,
    'C' => 80,
    'O' => 90,
    'M' => 100,
);

use Moo;
use namespace::clean;

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
    my ($self, $profile, $groups) = @_;

    $groups //= [];

    my %output;

    $output{lintian_version} = $ENV{LINTIAN_VERSION};

    my @allgroups_output;
    $output{groups} = \@allgroups_output;

    for my $group (sort { $a->name cmp $b->name } @{$groups}) {

        my %group_output;
        $group_output{group_id} = $group->name;
        $group_output{source_name} = $group->source_name;
        $group_output{source_version} = $group->source_version;

        push(@allgroups_output, \%group_output);

        my @allfiles_output;
        $group_output{input_files} = \@allfiles_output;

        for my $processable (sort {$a->path cmp $b->path}
            $group->get_processables) {

            my %file_output;
            $file_output{path} = $processable->path;
            $file_output{hints}
              = $self->hintlist($profile, $processable->hints);

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
    my ($self, $profile, $arrayref) = @_;

    my %sorter;
    for my $hint (@{$arrayref // []}) {

        my $tag = $profile->get_tag($hint->tag_name);

        my $override_status = 0;
        $override_status = 1
          if defined $hint->override || @{$hint->masks};

        my $ranking_code = $tag->code;
        $ranking_code = 'X'
          if $tag->experimental;
        $ranking_code = 'O'
          if defined $hint->override;
        $ranking_code = 'M'
          if @{$hint->masks};

        my $code_priority = $CODE_PRIORITY{$ranking_code};

        push(
            @{
                $sorter{$override_status}{$code_priority}{$tag->name}
                  {$hint->context}
            },
            $hint
        );
    }

    my @sorted;
    for my $override_status (sort keys %sorter) {
        my %by_code_priority = %{$sorter{$override_status}};

        for my $code_priority (sort { $a <=> $b } keys %by_code_priority) {
            my %by_tag_name = %{$by_code_priority{$code_priority}};

            for my $tag_name (sort keys %by_tag_name) {
                my %by_context = %{$by_tag_name{$tag_name}};

                for my $context (sort keys %by_context) {

                    my $hints
                      = $sorter{$override_status}{$code_priority}{$tag_name}
                      {$context};

                    push(@sorted, $_)for @{$hints};
                }
            }
        }
    }

    my @hint_dictionaries;
    for my $hint (@sorted) {

        my $tag = $profile->get_tag($hint->tag_name);

        my %hint_dictionary;
        push(@hint_dictionaries, \%hint_dictionary);

        $hint_dictionary{tag} = $tag->name;
        $hint_dictionary{note} = $hint->note;

        if ($hint->can('pointer')) {
            my $pointer = $hint->pointer;

            my %pointer_dictionary;

            if ($pointer->can('item')) {
                my $item = $pointer->item;

                my %item_dictionary;
                $item_dictionary{name} = $item->name;
                $item_dictionary{index} = $item->index->identifier;

                $pointer_dictionary{item} = \%item_dictionary;

                # numerify to force JSON integer
                # https://metacpan.org/pod/JSON::XS#simple-scalars
                $pointer_dictionary{line_position} = $pointer->position + 0;
            }

            $hint_dictionary{pointer} = \%pointer_dictionary;
        }

        $hint_dictionary{visibility} = $tag->visibility;
        $hint_dictionary{experimental}
          = ($tag->experimental ? JSON()->true : JSON()->false);

        for my $mask (@{ $hint->masks }) {

            my %mask_dictionary;
            $mask_dictionary{screen} = $mask->screen;
            $mask_dictionary{excuse} = $mask->excuse;

            push(@{$hint_dictionary{masks}}, \%mask_dictionary);
        }

        if ($hint->override) {

            my %override_dictionary;
            $override_dictionary{justification}
              = $hint->override->justification;

            $hint_dictionary{override} = \%override_dictionary;
        }
    }

    return \@hint_dictionaries;
}

=item describe_tags

=cut

sub describe_tags {
    my ($self, $data, $tags) = @_;

    my @tag_dictionaries;

    for my $tag (@{$tags}) {

        my %tag_dictionary;
        push(@tag_dictionaries, \%tag_dictionary);

        $tag_dictionary{name} = $tag->name;
        $tag_dictionary{name_spaced}
          = ($tag->name_spaced ? JSON()->true : JSON()->false);
        $tag_dictionary{show_always}
          = ($tag->show_always ? JSON()->true : JSON()->false);

        $tag_dictionary{explanation} = $tag->explanation;

        my @tag_see_also_markdown
          = map { markdown_citation($data, $_) } @{$tag->see_also};
        $tag_dictionary{see_also} = \@tag_see_also_markdown;

        $tag_dictionary{check} = $tag->check;
        $tag_dictionary{visibility} = $tag->visibility;
        $tag_dictionary{experimental}
          = ($tag->experimental ? JSON()->true : JSON()->false);

        $tag_dictionary{renamed_from} = $tag->renamed_from;

        my @screen_dictionaries;

        for my $screen (@{$tag->screens}) {

            my %screen_dictionary;
            push(@screen_dictionaries, \%screen_dictionary);

            $screen_dictionary{name} = $screen->name;

            my @advocate_emails = map { $_->format } @{$screen->advocates};
            $screen_dictionary{advocates} = \@advocate_emails;

            $screen_dictionary{reason} = $screen->reason;

            my @screen_see_also_markdown
              = map { markdown_citation($data, $_) } @{$screen->see_also};
            $screen_dictionary{see_also} = \@screen_see_also_markdown;
        }

        $tag_dictionary{screens} = \@screen_dictionaries;

        $tag_dictionary{lintian_version} = $ENV{LINTIAN_VERSION};
    }

    # convert to UTF-8 prior to encoding in JSON
    my $encoder = JSON->new;
    $encoder->canonical;
    $encoder->utf8;
    $encoder->pretty;

    # encode single tags without array bracketing
    my $object = \@tag_dictionaries;
    $object = shift @tag_dictionaries
      if @tag_dictionaries == 1;

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

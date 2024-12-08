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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Output::HTML;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Path::Tiny;
use Text::Markdown::Discount qw(markdown);
use Text::Xslate qw(mark_raw);
use Time::Duration;
use Time::Moment;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Output::Markdown qw(markdown_citation);

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $NEWLINE => qq{\n};
const my $PARAGRAPH_BREAK => $NEWLINE x 2;

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

with 'Lintian::Output::Grammar';

=head1 NAME

Lintian::Output::HTML - standalone HTML hint output

=head1 SYNOPSIS

    use Lintian::Output::HTML;

=head1 DESCRIPTION

Provides standalone HTML hint output.

=head1 INSTANCE METHODS

=over 4

=item issue_hints

Print all hints passed in array. A separate arguments with processables
is necessary to report in case no hints were found.

=cut

sub issue_hints {
    my ($self, $profile, $groups, $option) = @_;

    $groups //= [];

    my %output;

    my $lintian_version = $ENV{LINTIAN_VERSION};
    $output{'lintian-version'} = $lintian_version;

    my @allgroups_output;
    $output{groups} = \@allgroups_output;

    for my $group (sort { $a->name cmp $b->name } @{$groups}) {

        my %group_output;

        $group_output{'group-id'} = $group->name;
        $group_output{name} = $group->source_name;
        $group_output{version} = $group->source_version;

        my $start = Time::Moment->from_string($group->processing_start);
        my $end = Time::Moment->from_string($group->processing_end);
        $group_output{start} = $start->strftime('%c');
        $group_output{end} = $end->strftime('%c');
        $group_output{duration} = duration($start->delta_seconds($end));

        my @processables = $group->get_processables;
        my $any_processable = shift @processables;
        $group_output{'maintainer'}
          = $any_processable->fields->value('Maintainer');

        push(@allgroups_output, \%group_output);

        my @allfiles_output;
        $group_output{'input-files'} = \@allfiles_output;

        for my $processable (sort {$a->path cmp $b->path}
            $group->get_processables) {
            my %file_output;
            $file_output{filename} = path($processable->path)->basename;
            $file_output{hints}
              = $self->hintlist($profile, $option, $processable->hints);
            push(@allfiles_output, \%file_output);
        }
    }

    my @tag_infos;
    $output{tag_infos} = \@tag_infos;
    for my $tag_name (sort { $a cmp $b } keys %{$self->issuedtags}) {
        my $tag = %{$self->issuedtags}{$tag_name};
        my %data;
        $data{tag} = $tag;
        $data{description}
          = markdown($self->markdown_description($profile->data, $tag));
        push(@tag_infos, \%data);
    }

    my $style_sheet = $profile->data->style_sheet->css;

    my $templatedir = "$ENV{LINTIAN_BASE}/templates";
    my $tx = Text::Xslate->new(path => [$templatedir]);
    my $page = $tx->render(
        'standalone-html.tx',
        {
            title => 'Lintian Tags',
            style_sheet => mark_raw($style_sheet),
            output => \%output,
        }
    );

    print encode_utf8($page);

    return;
}

=item C<hintlist>

=cut

sub hintlist {
    my ($self, $profile, $option, $arrayref) = @_;

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

        if ($option->{info}) {

            $self->issue_tag($tag);
        }

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

    my @html_hints;
    for my $hint (@sorted) {

        my $tag = $profile->get_tag($hint->tag_name);

        my %html_hint;
        push(@html_hints, \%html_hint);

        $html_hint{tag_name} = $hint->tag_name;

        if ($option->{info}) {
            # Link to explanation generated on this page.
            $html_hint{url} = q{#} . $hint->tag_name;
        } else {
            # Link to the (now defunct) lintian.debian.org page.
            $html_hint{url}
              = 'https://lintian.debian.org/tags/' . $hint->tag_name;
        }

        $html_hint{context} = $hint->context
          if length $hint->context;

        $html_hint{visibility} = $tag->visibility;

        $html_hint{visibility} = 'experimental'
          if $tag->experimental;

        my @comments;
        if ($hint->override) {

            $html_hint{visibility} = 'override';

            push(@comments, $hint->override->justification)
              if length $hint->override->justification;
        }

        # order matters
        $html_hint{visibility} = 'mask'
          if @{ $hint->masks };

        for my $mask (@{$hint->masks}) {

            push(@comments, 'masked by screen ' . $mask->screen);
            push(@comments, $mask->excuse)
              if length $mask->excuse;
        }

        $html_hint{comments} = \@comments
          if @comments;
    }

    return \@html_hints;
}

=item describe_tags

=cut

sub describe_tags {
    my ($self, $data, $tags) = @_;

    for my $tag (@{$tags}) {

        say encode_utf8('<p>Name: ' . $tag->name . '</p>');
        say encode_utf8($EMPTY);

        print encode_utf8(markdown($self->markdown_description($data, $tag)));
    }

    return;
}

=item issuedtags

Hash containing the tags which have been issued.

=cut

has issuedtags => (is => 'rw', default => sub { {} });

=item C<issue_tag($tag)>

Register a tag to have its description included in the output.

=cut

sub issue_tag {
    my ($self, $tag) = @_;

    $self->issuedtags->{$tag->name} = $tag;

    return;
}

=item markdown_description

=cut

sub markdown_description {
    my ($self, $data, $tag) = @_;

    my $description = $tag->explanation;

    my @extras;

    if (@{$tag->see_also}) {

        my @markdown
          = map { markdown_citation($data, $_) } @{$tag->see_also};
        my $references
          = 'Please refer to '
          . $self->oxford_enumeration('and', @markdown)
          . ' for details.';

        push(@extras, $references);
    }

    push(@extras, 'Visibility: '. $tag->visibility);

    push(@extras, 'Check: ' . $tag->check)
      if length $tag->check;

    push(@extras, 'Renamed from: ' . join($SPACE, @{$tag->renamed_from}))
      if @{$tag->renamed_from};

    push(@extras, 'This tag is experimental.')
      if $tag->experimental;

    push(@extras,
        'This tag is a classification. There is no issue in your package.')
      if $tag->visibility eq 'classification';

    for my $screen (@{$tag->screens}) {

        my $screen_description = 'Screen: ' . $screen->name . $NEWLINE;
        $screen_description
          .= 'Advocates: ' . join(', ', @{$screen->advocates}) . $NEWLINE;
        $screen_description .= 'Reason: ' . $screen->reason . $NEWLINE;

        $screen_description .= 'See-Also: ' . $NEWLINE;

        push(@extras, $screen_description);
    }

    $description .= $PARAGRAPH_BREAK . $_ for @extras;

    return $description;
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

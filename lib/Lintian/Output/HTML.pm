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

package Lintian::Output::HTML;

use v5.20;
use warnings;
use utf8;
use autodie;

use Text::Markdown::Discount qw(markdown);
use Text::Xslate;
use Time::Duration;
use Time::Moment;

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant NEWLINE => qq{\n};

use Path::Tiny;

use Moo;
use namespace::clean;

with 'Lintian::Output';

=head1 NAME

Lintian::Output::HTML - standalone HTML hint output

=head1 SYNOPSIS

    use Lintian::Output::HTML;

=head1 DESCRIPTION

Provides standalone HTML hint output.

=head1 INSTANCE METHODS

=over 4

=item BUILD

=cut

sub BUILD {
    my ($self, $args) = @_;

    $self->delimiter(EMPTY);

    return;
}

=item issue_hints

Print all hints passed in array. A separate arguments with processables
is necessary to report in case no hints were found.

=cut

my %code_priority = (
    'E' => 30,
    'W' => 40,
    'I' => 50,
    'P' => 60,
    'X' => 70,
    'C' => 80,
    'O' => 90,
);

sub issue_hints {
    my ($self, $groups) = @_;

    $groups //= [];

    my %output;

    my $lintian_version = $ENV{LINTIAN_VERSION};
    $output{'lintian-version'} = $lintian_version;

    my @allgroups_output;
    $output{groups} = \@allgroups_output;

    for my $group (sort { $a->name cmp $b->name } @{$groups}) {

        my %group_output;

        $group_output{'group-id'} = $group->name;
        my ($name, $version)  = split(m{/}, $group->name, 2);
        $group_output{'name'} = $name;
        $group_output{'version'} = $version;

        my $start = Time::Moment->from_string($group->processing_start);
        my $end = Time::Moment->from_string($group->processing_end);
        $group_output{start} = $start->strftime('%c');
        $group_output{end} = $end->strftime('%c');
        $group_output{duration} = duration($start->delta_seconds($end));

        $group_output{'maintainer'}
          = ($group->get_processables)[0]
          ->fields->unfolded_value('Maintainer');

        push(@allgroups_output, \%group_output);

        my @allfiles_output;
        $group_output{'input-files'} = \@allfiles_output;

        for my $processable (sort {$a->path cmp $b->path}
            $group->get_processables) {
            my %file_output;
            $file_output{filename} = path($processable->path)->basename;
            $file_output{tags}
              = $self->hintlist($lintian_version, $processable->hints);
            push(@allfiles_output, \%file_output);
        }
    }

    my $templatedir = "$ENV{LINTIAN_BASE}/templates";
    my $tx = Text::Xslate->new(path => [$templatedir]);
    my $page = $tx->render(
        'standalone-html.tx',
        {
            title => 'Lintian Tags',
            output => \%output,
        });

    print $page;

    return;
}

=item C<hintlist>

=cut

sub hintlist {
    my ($self, $lintian_version, $arrayref) = @_;

    my @hints;

    my @sorted = sort {
               defined $a->override <=> defined $b->override
          ||   $code_priority{$a->tag->code}<=> $code_priority{$b->tag->code}
          || $a->tag->name cmp $b->tag->name
          || $a->context cmp $b->context
    } @{$arrayref // []};

    for my $input (@sorted) {

        my %hint;
        push(@hints, \%hint);

        $hint{name} = $input->tag->name;

        $hint{url} = "https://lintian.debian.org/tags/$hint{name}.html";

        $hint{context} = $input->context
          if length $input->context;

        $hint{severity} = $input->tag->effective_severity;
        $hint{code} = uc substr($hint{severity}, 0, 1);

        $hint{experimental} = 'yes'
          if $input->tag->experimental;

        if ($input->override) {

            $hint{code} = 'O';

            my @comments = @{ $input->override->{comments} // [] };
            $hint{comments} = \@comments
              if @comments;
        }
    }

    return \@hints;
}

=item describe_tags

=cut

sub describe_tags {
    my ($self, @tags) = @_;

    for my $tag (@tags) {

        say '<p>Name: ' . $tag->name . '</p>';
        say EMPTY;

        print markdown($tag->markdown_description);
    }

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

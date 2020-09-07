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
use autodie;

use Time::Piece;
use JSON::MaybeXS;

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant NEWLINE => qq{\n};

use Moo;
use namespace::clean;

with 'Lintian::Output';

=head1 NAME

Lintian::Output::JSON - JSON tag output

=head1 SYNOPSIS

    use Lintian::Output::JSON;

=head1 DESCRIPTION

Provides JSON tag output.

=head1 INSTANCE METHODS

=over 4

=item BUILD

=cut

sub BUILD {
    my ($self, $args) = @_;

    $self->delimiter(EMPTY);

    return;
}

=item issue_tags

Print all tags passed in array. A separate arguments with processables
is necessary to report in case no tags were found.

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

sub issue_tags {
    my ($self, $groups) = @_;

    $groups //= [];

    my %output;

    $output{'lintian-version'} = $ENV{LINTIAN_VERSION};

    my @allgroups_output;
    $output{groups} = \@allgroups_output;

    for my $group (sort { $a->name cmp $b->name } @{$groups}) {

        my %group_output;
        $group_output{'group-id'} = $group->name;
        $group_output{'processing-start'} = $group->processing_start;
        $group_output{'processing-end'} = $group->processing_end;

        $group_output{'maintainer'}
          = ($group->get_processables)[0]
          ->fields->unfolded_value('Maintainer');

        push(@allgroups_output, \%group_output);

        my @allfiles_output;
        $group_output{'input-files'} = \@allfiles_output;

        for my $processable (sort {$a->path cmp $b->path}
            $group->get_processables) {
            my %file_output;
            $file_output{path} = $processable->path;
            $file_output{tags} = $self->taglist($processable->tags);
            push(@allfiles_output, \%file_output);
        }
    }

    # convert to UTF-8 prior to encoding in JSON
    my $encoder = JSON->new;
    $encoder->canonical;
    $encoder->utf8;
    $encoder->pretty;
    my $json = $encoder->encode(\%output);

    # duplicate STDOUT
    open(my $RAW, '>&', *STDOUT) or die 'Cannot dup STDOUT';

    # avoid all PerlIO layers such as utf8
    binmode($RAW, ':raw');

    # output encoded JSON to the raw handle
    print {$RAW} $json;

    close $RAW;

    return;
}

=item C<taglist>

=cut

sub taglist {
    my ($self, $arrayref) = @_;

    my @tags;

    my @sorted = sort {
               defined $a->override <=> defined $b->override
          ||   $code_priority{$a->info->code}<=> $code_priority{$b->info->code}
          || $a->name cmp $b->name
          || $a->context cmp $b->context
    } @{$arrayref // []};

    for my $input (@sorted) {

        my %tag;
        push(@tags, \%tag);

        $tag{name} = $input->info->name;

        $tag{context} = $input->context
          if length $input->context;

        $tag{severity} = $input->info->effective_severity;
        $tag{experimental} = 'yes'
          if $input->info->experimental;

        if ($input->override) {

            $tag{override} = 'yes';

            my @comments = @{ $input->override->{comments} // [] };
            $tag{'override-comments'} = \@comments
              if @comments;
        }
    }

    return \@tags;
}

=item tag_description

=cut

sub tag_description {
    my ($self, $tag_info) = @_;

    my %output;

    $output{Name} = $tag_info->name;
    $output{'Name-Spaced'} = $tag_info->name_spaced
      if length $tag_info->name_spaced;

    $output{Explanation} = $tag_info->explanation;
    $output{'See-Also'} = $tag_info->see_also
      if @{$tag_info->see_also};

    $output{Check} = $tag_info->check;
    $output{Visibility} = $tag_info->visibility;
    $output{Experimental} = $tag_info->experimental
      if length $tag_info->experimental;

    $output{'Renamed-From'} = $tag_info->renamed_from
      if @{$tag_info->renamed_from};

    # convert to UTF-8 prior to encoding in JSON
    my $encoder = JSON->new;
    $encoder->canonical;
    $encoder->utf8;
    $encoder->pretty;

    my $json = $encoder->encode(\%output);

    # duplicate STDOUT
    open(my $RAW, '>&', *STDOUT) or die 'Cannot dup STDOUT';

    # avoid all PerlIO layers such as utf8
    binmode($RAW, ':raw');

    # output encoded JSON to the raw handle
    print {$RAW} $json;

    close $RAW;

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

# Copyright © 2008 Frank Lichtenheld <frank@lichtenheld.de>
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

package Lintian::Output::XML;

use v5.20;
use warnings;
use utf8;

use Time::Piece;
use XML::Writer;

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant NEWLINE => qq{\n};

use Moo;
use namespace::clean;

with 'Lintian::Output';

=head1 NAME

Lintian::Output::XML - XML tag output

=head1 SYNOPSIS

    use Lintian::Output::XML;

=head1 DESCRIPTION

Provides XML tag output.

=head1 INSTANCE METHODS

=over 4

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

    my $writer
      = XML::Writer->new(OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT => 2);

    $writer->xmlDecl('utf-8');

    $writer->startTag('lintian-run');
    $writer->dataElement('lintian-version', $ENV{LINTIAN_VERSION})
      if length $ENV{LINTIAN_VERSION};

    $writer->startTag('groups');

    for my $group (@{$groups // []}) {

        $writer->startTag('group');

        # grab group data from first processable
        my $first = ($group->get_processables)[0];

        $writer->dataElement('source-name', $first->source);
        $writer->dataElement('source-version', $first->source_version);
        $writer->dataElement('run-start', gmtime->datetime);

        $writer->startTag('input-files');

        my @singles = grep { defined }
          map { $group->$_ } ('source', 'changes', 'buildinfo');
        for my $processable (@singles) {

            $writer->startTag($processable->type);
            $self->taglist($writer, $processable->tags);
            $writer->endTag($processable->type);
        }

        my @installables = $group->get_binary_processables;
        if (@installables) {

            $writer->startTag('installables');

            my @sorted = sort { $a->type cmp $b->type } @installables;
            for my $processable (@sorted) {

                $writer->startTag('installable');

                $writer->dataElement('package-name', $processable->name);
                $writer->dataElement('version', $processable->version)
                  if $processable->version ne $first->source_version;

                $writer->dataElement('architecture',
                    $processable->architecture);

                my $container = $processable->type;
                $container =~ s/^binary$/deb/;
                $writer->dataElement('container', $container);

                $self->taglist($writer, $processable->tags);

                $writer->endTag('installable');
            }

            $writer->endTag('installables');
        }

        $writer->endTag('input-files');
        $writer->endTag('group');
    }

    $writer->endTag('groups');

    $writer->endTag('lintian-run');
    $writer->end();

    print { $self->stdout } $writer->to_string;

    return;
}

=item C<taglist>

=cut

sub taglist {
    my ($self, $writer, $tags) = @_;

    $writer->startTag('tags');

    my @sorted = sort {
               defined $a->override <=> defined $b->override
          ||   $code_priority{$a->info->code}<=> $code_priority{$b->info->code}
          || $a->name cmp $b->name
          || $a->hint cmp $b->hint
    } @{$tags // []};

    for my $tag (@sorted) {

        $writer->startTag('tag',(severity => $tag->info->effective_severity,));

        $writer->dataElement('name', $tag->info->name);

        my $printable = $tag->hint;
        $printable =~ s/[^[:print:]]/?/g;

        $writer->dataElement('hint', $printable)
          if length $printable;

        $writer->dataElement('experimental', 'yes')
          if $tag->info->experimental;

        if ($tag->override) {

            $writer->startTag('override');
            $writer->dataElement('origin', 'maintainer');

            my @comments = @{ $tag->override->{comments} // [] };
            if (@comments) {

                $writer->startTag('comments');
                $writer->dataElement('line', $_) for @comments;
                $writer->endTag('comments');
            }

            $writer->endTag('override');
        }

        $writer->endTag('tag');

        $self->issuedtags->{$tag->info->name}++;
    }

    $writer->endTag('tags');

    return;
}

sub _delimiter {
    return;
}

sub _print {
    my ($self, $stream, $lead, @args) = @_;
    $stream ||= $self->stderr;
    my $output = $self->string($lead, @args);
    print {$stream} $output;
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

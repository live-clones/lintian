# Copyright © 2008 Jordà Polo <jorda@ettin.org>
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

package Lintian::Output::LetterQualifier;

use v5.20;
use warnings;
use utf8;

use Term::ANSIColor qw(colored);
use Lintian::Tag::Info ();

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant NEWLINE => qq{\n};

use Moo;
use namespace::clean;

with 'Lintian::Output';

my %codes = (
    'classification' => 'C',
    'pedantic' => 'P',
    'info' => 'I',
    'warning' => 'W',
    'error' => 'E',
);

my %lq_default_colors = (
    'pedantic' => 'green',
    'info' => 'cyan',
    'warning' => 'yellow',
    'error' => 'red',
);

=head1 NAME

Lintian::Output::LetterQualifier - letter qualifier tag output

=head1 SYNOPSIS

    use Lintian::Output::LetterQualifier;

=head1 DESCRIPTION

Provides letter qualifier tag output.

=head1 INSTANCE METHODS

=over 4

=item BUILD

=cut

sub BUILD {
    my ($self) = @_;

    $self->colors({%lq_default_colors});

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

my %type_priority = (
    'source' => 30,
    'binary' => 40,
    'udeb' => 50,
    'changes' => 60,
    'buildinfo' => 70,
);

sub issue_tags {
    my ($self, $groups) = @_;

    my @processables = map { $_->get_processables } @{$groups // []};

    my @pending;
    for my $processable (@processables) {

        # get tags
        my @tags = @{$processable->tags};

        # associate tags with processable
        $_->processable($processable) for @tags;

        # remove circular references
        $processable->tags([]);

        push(@pending, @tags);
    }

    $self->print_start_pkg($_) for @processables;

    my @sorted = sort {
             defined $a->override <=> defined $b->override
          || $code_priority{$a->info->code} <=> $code_priority{$b->info->code}
          || $a->name cmp $b->name
          || $type_priority{$a->processable->type}
          <=> $type_priority{$b->processable->type}
          || $a->processable->name cmp $b->processable->name
          || $a->hint cmp $b->hint
    } @pending;

    $self->print_tag($_) for @sorted;

    return;
}

=item print_tag

=cut

sub print_tag {
    my ($self, $tag) = @_;

    my $tag_info = $tag->info;
    my $information = $tag->hint;
    my $override = $tag->override;
    my $processable = $tag->processable;

    my $code = $tag_info->code;
    $code = 'X' if $tag_info->experimental;
    $code = 'O' if defined($override);

    my $severity = $tag_info->effective_severity;
    my $lq = $codes{$severity};

    my $pkg = $processable->name;
    my $type
      = ($processable->type ne 'binary') ? SPACE . $processable->type : EMPTY;

    my $tagname = $tag_info->name;

    $information = ' ' . $self->_quote_print($information)
      if $information ne '';

    if ($self->_do_color) {
        my $color = $self->colors->{$severity};
        $lq = colored($lq, $color);
        $tagname = colored($tagname, $color);
    }

    $self->_print('', "$code\[$lq\]: $pkg$type", "$tagname$information");
    if (not $self->issued_tag($tag_info->name) and $self->showdescription) {
        my $description = $tag_info->description('text', '   ');
        $self->_print('', 'N', '');
        $self->_print('', 'N', split("\n", $description));
        $self->_print('', 'N', '');
    }
    return;
}

=item C<print_start_pkg($pkg_info)>

Called before lintian starts to handle each package.  The version in
Lintian::Output uses v_msg() for output.  Called from Tags::select_pkg().

=cut

sub print_start_pkg {
    my ($self, $processable) = @_;

    my $object = 'package';
    $object = 'file'
      if $processable->type eq 'changes';

    $self->v_msg(
        $self->delimiter,
        'Processing '. $processable->type. " $object ". $processable->name,
        '(version '
          . $processable->version
          . ', arch '
          . $processable->architecture . ') ...'
    );
    return;
}

=item C<_quote_print($string)>

Called to quote a string.  By default it will replace all
non-printables with "?".  Sub-classes can override it if
they allow non-ascii printables etc.

=cut

sub _quote_print {
    my ($self, $string) = @_;
    $string =~ s/[^[:print:]]/?/go;
    return $string;
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

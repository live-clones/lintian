# Tags::ColonSeparated -- Perl tags functions for lintian
# $Id: Tags.pm 489 2005-09-17 00:06:30Z djpig $

# Copyright (C) 2005,2008 Frank Lichtenheld <frank@lichtenheld.de>
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

package Lintian::Output::ColonSeparated;

use strict;
use warnings;

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant COLON => q{:};
use constant NEWLINE => qq{\n};

use Moo;
use namespace::clean;

with 'Lintian::Output';

=head1 NAME

Lintian::Output::ColonSeparated - colon-separated tag output

=head1 SYNOPSIS

    use Lintian::Output::ColonSeparated;

=head1 DESCRIPTION

Provides colon-separated tag output.

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

my %type_priority = (
    'source' => 30,
    'binary' => 40,
    'udeb' => 50,
    'changes' => 60,
    'buildinfo' => 70,
);

sub issue_tags {
    my ($self, $pending, $processables) = @_;

    return
      unless $pending && $processables;

    $self->print_start_pkg($_)for @{$processables};

    my @sorted = sort {
             defined $a->override <=> defined $b->override
          || $code_priority{$a->info->code} <=> $code_priority{$b->info->code}
          || $a->name cmp $b->name
          || $type_priority{$a->processable->type}
          <=> $type_priority{$b->processable->type}
          || $a->processable->name cmp $b->processable->name
          || $a->extra cmp $b->extra
    } @{$pending};

    $self->print_tag($_) for @sorted;

    return;
}

=item print_tag

=cut

sub print_tag {
    my ($self, $tag) = @_;

    my $tag_info = $tag->info;
    my $information = $tag->extra;
    my $override = $tag->override;
    my $processable = $tag->processable;

    my $odata = EMPTY;
    if ($override) {
        $odata = $override->{tag};
        my $extra = $override->{extra};
        $extra =~ s/[^[:print:]]/?/g;
        $odata .= SPACE . $extra
          if length $extra;
    }

    $self->issuedtags->{$tag_info->tag}++;

    $information =~ s/[^[:print:]]/?/g;

    my @args = (
        'tag',
        $tag_info->code,
        $tag_info->severity,
        $tag_info->certainty,
        ($tag_info->experimental ? 'X' : EMPTY)
          . (defined $override ? 'O' : EMPTY),
        $processable->name,
        $processable->version,
        $processable->architecture,
        $processable->type,
        $tag_info->tag,
        $information,
        $odata,
    );

    my @quoted = map {
        s/\\/\\\\/g;
        s/\Q:\E/\\:/g;
        $_
    } @args;

    my $output = join(COLON, @quoted) . NEWLINE;
    print {$self->stdout} $output;

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

sub _delimiter {
    return;
}

sub _message {
    my ($self, @args) = @_;

    foreach (@args) {
        $self->_print('message', $_);
    }
    return;
}

sub _warning {
    my ($self, @args) = @_;

    foreach (@args) {
        $self->_print('warning', $_);
    }
    return;
}

sub _print {
    my ($self, @args) = @_;

    my $output = $self->string(@args);
    print {$self->stdout} $output;
    return;
}

=item string

=cut

sub string {
    my ($self, @args) = @_;

    return join(':', _quote_char(':', @args))."\n";
}

sub _quote_char {
    my ($char, @items) = @_;

    foreach (@items) {
        s/\\/\\\\/go;
        s/\Q$char\E/\\$char/go;
    }

    return @items;
}

=back

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

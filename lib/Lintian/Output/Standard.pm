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

package Lintian::Output::Standard;

use v5.20;
use warnings;
use utf8;

use HTML::Entities;
use Term::ANSIColor ();

# for tty hyperlinks
use constant OSC_HYPERLINK => qq{\033]8;;};
use constant OSC_DONE => qq{\033\\};

use constant SPACE => q{ };

use Moo;
use namespace::clean;

with 'Lintian::Output';

=head1 NAME

Lintian::Output::Standard - standard tag output

=head1 SYNOPSIS

    use Lintian::Output::Standard;

=head1 DESCRIPTION

Provides standard tag output.

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
          || $a->context cmp $b->context
    } @pending;

    $self->print_tag($_) for @sorted;

    return;
}

=item C<print_tag($pkg_info, $tag_info, $context, $override)>

Print a tag.  The first two arguments are hash reference with the
information about the package and the tag, $context is the context
information for the tag (if any) as an array reference, and $override
is either undef if the tag is not overridden or a hash with
override info for this tag.

=cut

sub print_tag {
    my ($self, $tag) = @_;

    my $tag_info = $tag->info;
    my $information = $tag->context;
    my $override = $tag->override;
    my $processable = $tag->processable;

    $information = ' ' . $self->_quote_print($information)
      if $information ne '';
    my $code = $tag_info->code;
    my $tag_color = ($tag->override ? 'bright_black' : $self->{colors}{$code});
    my $fpkg_info= $self->_format_pkg_info($processable, $tag_info, $override);
    my $tag_name = $tag_info->name;
    my $limit = $self->tag_display_limit;
    my $output;

    # Limit the output so people do not drown in tags.  Some tags are
    # insanely noisy (hi static-library-has-unneeded-section)
    if ($limit) {
        my $proc_id = $processable->identifier;
        my $emitted_count
          = $self->{'proc_id2tag_count'}{$proc_id}{$tag_name}++;
        return if $emitted_count >= $limit;
        my $msg
          = ' ... use --no-tag-display-limit to see all (or pipe to a file/program)';
        $information = $self->_quote_print($msg)
          if $emitted_count >= $limit-1;
    }
    if ($self->_do_color && $self->color eq 'html') {
        my $escaped = encode_entities($tag_name);
        $information = encode_entities($information);
        $output .= qq(<span style="color: $tag_color">$escaped</span>);

    } else {
        my $text = $tag_name;
        $text = Term::ANSIColor::colored($tag_name, $tag_color)
          if $self->_do_color;

        if ($self->tty_hyperlinks) {
            my $target
              = 'https://lintian.debian.org/tags/' . $tag_name . '.html';
            $output .= $self->osc_hyperlink($text, $target);
        } else {
            $output .= $text;
        }
    }

    if ($override && @{ $override->{comments} }) {
        foreach my $c (@{ $override->{comments} }) {
            $self->msg($self->_quote_print($c));
        }
    }

    $self->_print('', $fpkg_info, "$output$information");
    if (not $self->issued_tag($tag_info->name) and $self->showdescription) {
        my $description;
        if ($self->_do_color && $self->color eq 'html') {
            $description = $tag_info->description('html', '   ');
        } else {
            $description = $tag_info->description('text', '   ');
        }
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
    $string =~ s/[^[:print:]]/?/g;
    return $string;
}

=item C<osc_hyperlink>

=cut

sub osc_hyperlink {
    my ($self, $text, $target) = @_;

    my $start = OSC_HYPERLINK . $target . OSC_DONE;
    my $end = OSC_HYPERLINK . OSC_DONE;

    return $start . $text . $end;
}

# Helper function to "print_tag" to decide the output format of the tag line.  Used by
# the "FullEWI" subclass.
#
sub _format_pkg_info {
    my ($self, $processable, $tag_info, $override) = @_;
    my $code = $tag_info->code;
    $code = 'X' if $tag_info->experimental;
    $code = 'O' if defined $override;
    my $type = '';
    $type = SPACE . $processable->type if $processable->type ne 'binary';
    return "$code: " . $processable->name . $type;
}

=back

=cut

1;

__END__

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

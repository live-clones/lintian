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

package Lintian::Output;

use strict;
use warnings;
use v5.8.0; # for PerlIO

use CGI qw(escapeHTML);
use List::MoreUtils qw(uniq);

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Output - Lintian messaging handling

=head1 SYNOPSIS

    # non-OO
    use Lintian::Output qw(:messages);

    $Lintian::Output::GLOBAL->verbosity_level(1);

    msg("Something interesting");
    v_msg("Something less interesting");
    debug_msg(3, "Something very specific");

    # OO
    use Lintian::Output;

    my $out = Lintian::Output->new;

    $out->verbosity_level(-1);
    $out->msg("Something interesting");
    $out->v_msg("Something less interesting");
    $out->debug_msg(3, "Something very specific");

=head1 DESCRIPTION

Lintian::Output is used for all interaction between lintian and the user.
It is designed to be easily extensible via subclassing.

To simplify usage in the most common cases, many Lintian::Output methods
can be used as class methods and will therefore automatically use the object
$Lintian::Output::GLOBAL unless their first argument C<isa('Lintian::Output')>.

=head1 ATTRIBUTES

The following fields impact the behavior of Lintian::Output.

=over 4

=item color

Can take the values "never", "always", "auto" or "html".

Whether to colorize tags based on their severity.  The default is "never",
which never uses color.  "always" will always use color, "auto" will use
color only if the output is going to a terminal.

"html" will output HTML <span> tags with a color style attribute (instead
of ANSI color escape sequences).

=item colors

=item debug

If set to a positive integer, will enable all debug messages issued with
a level lower or equal to its value.

=item issuedtags

Hash containing the names of tags which have been issued.

=item perf_debug

=item perf_log_fd

=item proc_id2tag_count

=item stdout

I/O handle to use for output of messages and tags.  Defaults to C<\*STDOUT>.

=item stderr

I/O handle to use for warnings.  Defaults to C<\*STDERR>.

=item showdescription

Whether to show the description of a tag when printing it.

=item tty_hyperlinks

=item tag_display_limit

Get/Set the number of times a tag is emitted per processable.

=item verbosity_level

Determine how verbose the output should be.  "0" is the default value
(tags and msg only), "-1" is quiet (tags only) and "1" is verbose
(tags, msg and v_msg).

=back

=cut

has color => (is => 'rw', default => 'never');
has colors => (
    is => 'rw',
    default => sub {
        {
            'E' => 'red',
            'W' => 'yellow',
            'I' => 'cyan',
            'P' => 'green',
            'C' => 'blue',
        }
    });
has issuedtags => (is => 'rw', default => sub { {} });
has perf_debug => (is => 'rw', default => 0);
has perf_log_fd => (is => 'rw', default => sub { \*STDOUT });
has proc_id2tag_count => (is => 'rw', default => sub { {} });
has stderr => (is => 'rw', default => sub { \*STDERR });
has stdout => (is => 'rw', default => sub { \*STDOUT });
has tag_display_limit => (is => 'rw', default => 4);
has tty_hyperlinks => (is => 'rw', default => 0);
has verbosity_level => (is => 'rw', default => 0);

has debug => (is => 'rw', default => sub { {} });
has showdescription => (is => 'rw', default => sub { {} });

=head1 CLASS/INSTANCE METHODS

These methods can be used both with and without an object.  If no object
is given, they will fall back to the $Lintian::Output::GLOBAL object.

=over 4

=item C<msg(@args)>

Will output the strings given in @args, one per line, each line prefixed
with 'N: '.  Will do nothing if verbosity_level is less than 0.

=item C<v_msg(@args)>

Will output the strings given in @args, one per line, each line prefixed
with 'N: '.  Will do nothing unless verbosity_level is greater than 0.

=item C<debug_msg($level, @args)>

$level should be a positive integer.

Will output the strings given in @args, one per line, each line prefixed
with 'N: '.  Will do nothing unless debug is set to a positive integer
>= $level.

=cut

sub msg {
    my ($self, @args) = @_;

    return if $self->verbosity_level < 0;
    $self->_message(@args);
    return;
}

sub v_msg {
    my ($self, @args) = @_;

    return unless $self->verbosity_level > 0;
    $self->_message(@args);
    return;
}

sub debug_msg {
    my ($self, $level, @args) = @_;

    return unless $self->debug && ($self->debug >= $level);

    $self->_message(@args);
    return;
}

=item C<warning(@args)>

Will output the strings given in @args on stderr, one per line, each line
prefixed with 'warning: '.

=cut

sub warning {
    my ($self, @args) = @_;

    return if $self->verbosity_level < 0;
    $self->_warning(@args);
    return;
}

=item  C<perf_log(@args)>

Like "v_msg", except output is possibly sent to a dedicated log
file.

Will output the strings given in @args, one per line.  The lines will
not be prefixed.  Will do nothing unless perf_debug is set to a
positive integer.

=cut

sub perf_log {
    my ($self, @args) = @_;

    return unless $self->perf_debug;

    $self->_print($self->perf_log_fd, '', @args);
    return;
}

=item C<delimiter()>

Gives back a string that is usable for separating messages in the output.
Note: This does not print anything, it just gives back the string, use
with one of the methods above, e.g.

 v_msg('foo', delimiter(), 'bar');

=cut

sub delimiter {
    my ($self) = @_;

    return $self->_delimiter;
}

=item C<issued_tag($tag_name)>

Indicate that the named tag has been issued.  Returns a boolean value
indicating whether the tag had previously been issued by the object.

=cut

sub issued_tag {
    my ($self, $tag_name) = @_;

    return $self->issuedtags->{$tag_name}++ ? 1 : 0;
}

=item C<string($lead, @args)>

TODO: Is this part of the public interface?

=cut

sub string {
    my ($self, $lead, @args) = @_;

    my $output = '';
    if (@args) {
        my $prefix = '';
        $prefix = "$lead: " if $lead;
        foreach (@args) {
            $output .= "${prefix}${_}\n";
        }
    } elsif ($lead) {
        $output .= $lead.".\n";
    }

    return $output;
}

=back

=head1 INSTANCE METHODS FOR SUBCLASSING

The following methods are only intended for subclassing and are
only available as instance methods.  The methods mentioned in
L</CLASS/INSTANCE METHODS>
usually only check whether they should do anything at all (according
to the values of verbosity_level and debug) and then call one of
the following methods to do the actual printing. Almost all of them
finally call _print() to do that.  This convoluted scheme is necessary
to be able to use the methods above as class methods and still make
the behaviour overridable in subclasses.

=over 4

=item C<_message(@args)>

Called by msg(), v_msg(), and debug_msg() to print the
message.

=cut

sub _message {
    my ($self, @args) = @_;

    $self->_print('', 'N', @args);
    return;
}

=item C<_warning(@args)>

Called by warning() to print the warning.

=cut

sub _warning {
    my ($self, @args) = @_;

    $self->_print($self->stderr, 'warning', @args);
    return;
}

=item C<_print($stream, $lead, @args)>

Called by _message(), _warning(), and print_tag() to do
the actual printing.

If you override these three methods, you can change
the calling convention for this method to pretty much
whatever you want.

The version in Lintian::Output prints the strings in
@args, one per line, each line preceded by $lead to
the I/O handle given in $stream.

=cut

sub _print {
    my ($self, $stream, $lead, @args) = @_;
    $stream ||= $self->stdout;

    my $output = $self->string($lead, @args);
    print {$stream} $output;
    return;
}

=item C<_delimiter()>

Called by delimiter().

=cut

sub _delimiter {
    return '----';
}

=item C<_do_color()>

Called by print_tag() to determine whether to produce colored
output.

=cut

sub _do_color {
    my ($self) = @_;

    return (
             $self->color eq 'always'
          || $self->color eq 'html'
          || ($self->color eq 'auto'
            && -t $self->stdout));
}

1;

__END__

=back

=head1 EXPORTS

Lintian::Output exports nothing by default, but the following export
tags are available:

=over 4

=item :messages

Exports all the methods in L</CLASS/INSTANCE METHODS>

=item :util

Exports all the methods in L<CLASS METHODS>

=back

=head1 SEE ALSO

lintian(1)

=cut

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

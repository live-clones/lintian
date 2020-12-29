# Copyright © 2008 Frank Lichtenheld <frank@lichtenheld.de>
# Copyright © 2018 Chris Lamb <lamby@debian.org>
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

use v5.20;
use warnings;
use utf8;

use Unicode::UTF8 qw(encode_utf8);

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Output - Lintian messaging handling

=head1 SYNOPSIS

    use Lintian::Output;

    my $out = Lintian::Output->new;

=head1 DESCRIPTION

Lintian::Output is used for all interaction between lintian and the user.
It is designed to be easily extensible via subclassing.

To simplify usage in the most common cases, many Lintian::Output methods
can be used as class methods and will therefore automatically use the object
$Lintian::Output::GLOBAL unless their first argument C<isa('Lintian::Output')>.

=head1 ATTRIBUTES

The following fields impact the behavior of Lintian::Output.

=over 4

=item html

=item color

=item colors

=item proc_id2tag_count

=item showdescription

Whether to show the description of a tag when printing it.

=item tty_hyperlinks

=item tag_display_limit

Get/Set the number of times a tag is emitted per processable.

=item verbosity

Determine how verbose the output should be.  "0" is the default value
(tags and msg only), "-1" is quiet (tags only) and "1" is verbose
(tags, msg and v_msg).

=item C<delimiter>

=back

=cut

has html => (is => 'rw', default => 0);
has color => (is => 'rw', default => 0);
has colors => (
    is => 'rw',
    default => sub {
        {
            'E' => 'red',
            'W' => 'yellow',
            'I' => 'cyan',
            'P' => 'green',
            'C' => 'blue',
            'O' => 'bright_black',
        }
    });
has proc_id2tag_count => (is => 'rw', default => sub { {} });
has tag_display_limit => (is => 'rw', default => 4);
has tty_hyperlinks => (is => 'rw', default => 0);
has verbosity => (is => 'rw', default => 0);

has showdescription => (is => 'rw', default => sub { {} });

has delimiter => (is => 'rw', default => '----');

=head1 CLASS/INSTANCE METHODS

These methods can be used both with and without an object.  If no object
is given, they will fall back to the $Lintian::Output::GLOBAL object.

=over 4

=item C<msg(@args)>

Will output the strings given in @args, one per line, each line prefixed
with 'N: '.  Will do nothing if verbosity is less than 0.

=item C<v_msg(@args)>

Will output the strings given in @args, one per line, each line prefixed
with 'N: '.  Will do nothing unless verbosity is greater than 0.

=item C<debug_msg($level, @args)>

$level should be a positive integer.

Will output the strings given in @args, one per line, each line prefixed
with 'N: '.  Will do nothing unless debug is set to a positive integer
>= $level.

=cut

sub msg {
    my ($self, @args) = @_;

    return
      if $self->verbosity < 0;

    say encode_utf8("N: $_") for @args;

    return;
}

sub v_msg {
    my ($self, @args) = @_;

    return
      unless $self->verbosity;

    say encode_utf8("N: $_") for @args;

    return;
}

=back

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

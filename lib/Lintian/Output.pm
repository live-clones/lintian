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
use base qw(Class::Accessor Exporter);

# Force export as soon as possible, since some of the modules we load also
# depend on us and the sequencing can cause things not to be exported
# otherwise.
our (@EXPORT, %EXPORT_TAGS, @EXPORT_OK);
BEGIN {
    @EXPORT = ();
    %EXPORT_TAGS = ( messages => [qw(msg v_msg warning debug_msg delimiter)],
		     util => [qw(_global_or_object)]);
    @EXPORT_OK = (@{$EXPORT_TAGS{messages}},
		  @{$EXPORT_TAGS{util}},
		  'string');
}

=head1 NAME

Lintian::Output - Lintian messaging handling

=head1 SYNOPSIS

    # non-OO
    use Lintian::Output qw(:messages);

    $Lintian::Output::GLOBAL->verbose(1);

    msg("Something interesting");
    v_msg("Something less interesting");
    debug_msg(3, "Something very specfific");

    # OO
    use Lintian::Output;

    my $out = new Lintian::Output;

    $out->quiet(1);
    $out->msg("Something interesting");
    $out->v_msg("Something less interesting");
    $out->debug_msg(3, "Something very specfific");

=head1 DESCRIPTION

Lintian::Output is used for all interaction between lintian and the user.
It is designed to be easily extendable via subclassing.

To simplify usage in the most common cases, many Lintian::Output methods
can be used as class methods and will therefor automatically use the object
$Lintian::Output::GLOBAL unless their first argument C<isa('Lintian::Output')>.

=cut

# support for ANSI color output via colored()
use Term::ANSIColor ();
use Lintian::Tag::Info ();
use Tags ();

=head1 ACCESSORS

The following fields define the behaviours of Lintian::Output.

=over 4

=item quiet

If true, will suppress all messages except for warnings.

=item verbose

If true, will enable messages issued with v_msg.

=item debug

If set to a positive integer, will enable all debug messages issued with
a level lower or equal to its value.

=item color

Can take the values "never", "always", "auto" or "html".

Whether to colorize tags based on their severity.  The default is "never",
which never uses color.  "always" will always use color, "auto" will use
color only if the output is going to a terminal.

"html" will output HTML <span> tags with a color style attribute (instead
of ANSI color escape sequences).

=item stdout

I/O handle to use for output of messages and tags.  Defaults to C<\*STDOUT>.

=item stderr

I/O handle to use for warnings.  Defaults to C<\*STDERR>.

=item showdescription

Whether to show the description of a tag when printing it.

=item issuedtags

Hash containing the names of tags which have been issued.

=back

=cut

Lintian::Output->mk_accessors(qw(verbose debug quiet color colors stdout
    stderr showdescription issuedtags));

# for the non-OO interface
my %default_colors = ( 'E' => 'red' , 'W' => 'yellow' , 'I' => 'cyan',
		       'P' => 'green' );

our $GLOBAL = new Lintian::Output;

sub new {
    my ($class, %options) = @_;
    my $self = { %options };

    bless($self, $class);

    $self->stdout(\*STDOUT);
    $self->stderr(\*STDERR);
    $self->colors({%default_colors});
    $self->issuedtags({});

    return $self;
}

=head1 CLASS/INSTANCE METHODS

These methods can be used both with and without an object.  If no object
is given, they will fall back to the $Lintian::Output::GLOBAL object.

=over 4

=item C<msg(@args)>

Will output the strings given in @args, one per line, each line prefixed
with 'N: '.  Will do nothing if quiet is true.

=item C<v_msg(@args)>

Will output the strings given in @args, one per line, each line prefixed
with 'N: '.  Will do nothing unless verbose is true.

=item C<debug_msg($level, @args)>

$level should be a positive integer.

Will output the strings given in @args, one per line, each line prefixed
with 'N: '.  Will do nothing unless debug is set to a positive integer
>= $level.

=cut

sub msg {
    my ($self, @args) = _global_or_object(@_);

    return if $self->quiet;
    $self->_message(@args);
}

sub v_msg {
    my ($self, @args) = _global_or_object(@_);

    return unless $self->verbose;
    $self->_message(@args);
}

sub debug_msg {
    my ($self, $level, @args) = _global_or_object(@_);

    return unless $self->debug && ($self->debug >= $level);

    $self->_message(@args);
}

=item C<warning(@args)>

Will output the strings given in @args on stderr, one per line, each line
prefixed with 'warning: '.

=cut

sub warning {
    my ($self, @args) = _global_or_object(@_);

    return if $self->quiet;
    $self->_warning(@args);
}

=item C<delimiter()>

Gives back a string that is usable for separating messages in the output.
Note: This does not print anything, it just gives back the string, use
with one of the methods above, e.g.

 v_msg('foo', delimiter(), 'bar');

=cut

sub delimiter {
    my ($self) = _global_or_object(@_);

    return $self->_delimiter;
}

=item C<issued_tag($tag_name)>

Indicate that the named tag has been issued.  Returns a boolean value
indicating whether the tag had previously been issued by the object.

=cut

sub issued_tag {
    my ($self, $tag_name) = _global_or_object(@_);

    return $self->issuedtags->{$tag_name}++ ? 1 : 0;
}

=item C<string($lead, @args)>

TODO: Is this part of the public interface?

=cut

sub string {
    my ($self, $lead, @args) = _global_or_object(@_);

    my $output = '';
    if (@args) {
	foreach (@args) {
	    $output .= $lead.': '.$_."\n";
	}
    } elsif ($lead) {
	$output .= $lead.".\n";
    }

    return $output;
}

=back

=head1 INSTANCE METHODS FOR CONTEXT-AWARE OUTPUT

The following methods are designed to be called at specific points
during program execution and require very specific arguments.  They
can only be called as instance methods.

=over 4

=item C<print_tag($pkg_info, $tag_info, $extra)>

Print a tag.  The first two arguments are hash reference with the information
about the package and the tag, $extra is the extra information for the tag
(if any) as an array reference.  Called from Tags::tag().

=cut

sub print_tag {
    my ($self, $pkg_info, $tag_info, $information) = @_;
    $information = ' ' . $information if $information ne '';
    my $code = Tags::get_tag_code($tag_info);
    my $tag_color = $self->{colors}{$code};
    $code = 'X' if exists $tag_info->{experimental};
    $code = 'O' if $tag_info->{overridden}{override};
    my $type = '';
    $type = " $pkg_info->{type}" if $pkg_info->{type} ne 'binary';

    my $tag;
    if ($self->_do_color) {
	if ($self->color eq 'html') {
	    my $escaped = $tag_info->{tag};
	    $escaped =~ s/&/&amp;/g;
	    $escaped =~ s/</&lt;/g;
	    $escaped =~ s/>/&gt;/g;
	    $tag .= qq(<span style="color: $tag_color">$escaped</span>)
	} else {
	    $tag .= Term::ANSIColor::colored($tag_info->{tag}, $tag_color);
	}
    } else {
	$tag .= $tag_info->{tag};
    }

    $self->_print('', "$code: $pkg_info->{pkg}$type", "$tag$information");
    if (!$self->issued_tag($tag_info->{tag}) and $self->showdescription) {
	my $info = Lintian::Tag::Info->new($tag_info->{tag});
	if ($info) {
	    my $description;
	    if ($self->_do_color && $self->color eq 'html') {
		$description = $info->description('html', '   ');
	    } else {
		$description = $info->description('text', '   ');
	    }
	    $self->_print('', 'N', '');
	    $self->_print('', 'N', split("\n", $description));
	    $self->_print('', 'N', '');
	}
    }
}

=item C<print_start_pkg($pkg_info)>

Called before lintian starts to handle each package.  The version in
Lintian::Output uses v_msg() for output.  Called from Tags::select_pkg().

=cut

sub print_start_pkg {
    my ($self, $pkg_info) = @_;

    $self->v_msg($self->delimiter,
		 "Processing $pkg_info->{type} package $pkg_info->{pkg} (version $pkg_info->{version}) ...");
}

=item C<print_start_pkg($pkg_info)>

Called after lintian is finished with a package.  The version in
Lintian::Output does nothing.  Called from Tags::select_pkg() and
Tags::reset_pkg().

=cut

sub print_end_pkg {
}

=back

=head1 INSTANCE METHODS FOR SUBCLASSING

The following methods are only intended for subclassing and are
only available as instance methods.  The methods mentioned in
L<CLASS/INSTANCE METHODS>
usually only check whether they should do anything at all (according
to the values of quiet, verbose, and debug) and then call one of
the following methods to do the actual printing. Allmost all of them
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
}

=item C<_warning(@args)>

Called by warning() to print the warning.

=cut

sub _warning {
    my ($self, @args) = @_;

    $self->_print($self->stderr, 'warning', @args);
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

    return ($self->color eq 'always' || $self->color eq 'html'
	    || ($self->color eq 'auto'
		&& -t $self->stdout));
}

=back

=head1 CLASS METHODS

=over 4

=item C<_global_or_object(@args)>

If $args[0] is a object which satisfies C<isa('Lintian::Output')>
returns @args, otherwise returns C<($Lintian::Output::GLOBAL, @_)>.

=back

=cut

sub _global_or_object {
    if (ref($_[0]) and $_[0]->isa('Lintian::Output')) {
	return @_;
    } else {
	return ($Lintian::Output::GLOBAL, @_);
    }
}

1;
__END__

=head1 EXPORTS

Lintian::Output exports nothing by default, but the following export
tags are available:

=over 4

=item :messages

Exports all the methods in L<CLASS/INSTANCE METHODS>

=item :util

Exports all the methods in L<CLASS METHODS>

=back

=head1 AUTHOR

Originally written by Frank Lichtenheld <djpig@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

# Local Variables:
# indent-tabs-mode: t
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 ts=8 noet shiftround

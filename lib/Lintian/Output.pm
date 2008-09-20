# Copyright (C) 2008 Frank Lichtenheld <frank@lichtenheld.de>
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

# support for ANSI color output via colored()
use Term::ANSIColor ();
use Tags ();

use base qw(Class::Accessor Exporter);
Lintian::Output->mk_accessors(qw(verbose debug quiet color colors stdout stderr));

our @EXPORT = ();
our %EXPORT_TAGS = ( messages => [qw(msg v_msg warning debug_msg delimiter)],
		     util => [qw(_global_or_object)]);
our @EXPORT_OK = (@{$EXPORT_TAGS{messages}},
		  @{$EXPORT_TAGS{util}},
		  'string');

# for the non-OO interface
our $GLOBAL = new Lintian::Output;

my %default_colors = ( 'E' => 'red' , 'W' => 'yellow' , 'I' => 'cyan' );

sub new {
    my ($class, %options) = @_;
    my $self = { %options };

    bless($self, $class);

    $self->stdout(\*STDOUT);
    $self->stderr(\*STDERR);
    $self->colors({%default_colors});

    return $self;
}

sub debug_msg {
    my ($self, $level, @args) = _global_or_object(@_);

    return unless $self->debug && ($self->debug >= $level);

    $self->_message(@args);
}

sub warning {
    my ($self, @args) = _global_or_object(@_);

    return if $self->quiet;
    $self->_warning(@args);
}

sub v_msg {
    my ($self, @args) = _global_or_object(@_);

    return unless $self->verbose;
    $self->_message(@args);
}

sub msg {
    my ($self, @args) = _global_or_object(@_);

    return if $self->quiet;
    $self->_message(@args);
}

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

sub print_tag {
    my ( $self, $pkg_info, $tag_info, $information ) = _global_or_object(@_);

    my $extra = '';
    $extra = " @$information" if @$information;
    $extra = '' if $extra eq ' ';
    my $code = Tags::get_tag_code($tag_info);
    my $tag_color = $self->{colors}{$code};
    $code = 'X' if exists $tag_info->{experimental};
    $code = 'O' if $tag_info->{overridden}{override};
    my $type = '';
    $type = " $pkg_info->{type}" if $pkg_info->{type} ne 'binary';

    my $tag;
    if ($self->_do_color) {
	$tag .= Term::ANSIColor::colored($tag_info->{tag}, $tag_color);
    } else {
	$tag .= $tag_info->{tag};
    }

    $self->_print('', "$code: $pkg_info->{pkg}$type", "$tag$extra");
}

sub _do_color {
    my ($self) = @_;

    return ($self->color eq 'always'
	    || ($self->color eq 'auto'
		&& -t $self->stdout));
}

sub delimiter {
    my ($self) = _global_or_object(@_);

    return $self->_delimiter;
}

sub _delimiter {
    return '----';
}

sub _message {
    my ($self, @args) = @_;

    $self->_print('', 'N', @args);
}

sub _warning {
    my ($self, @args) = @_;

    $self->_print($self->stderr, 'warning', @args);
}

sub _print {
    my ($self, $stream, $lead, @args) = @_;
    $stream ||= $self->stdout;

    my $output = $self->string($lead, @args);
    print {$stream} $output;
}

sub _global_or_object {
    if (ref($_[0]) and $_[0]->isa('Lintian::Output')) {
	return @_;
    } else {
	return ($Lintian::Output::GLOBAL, @_);
    }
}

1;

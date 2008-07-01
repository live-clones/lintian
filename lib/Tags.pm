# Tags -- Perl tags functions for lintian
# $Id$

# Copyright (C) 1998-2004 Various authors
# Copyright (C) 2005 Frank Lichtenheld <frank@lichtenheld.de>
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

package Tags;
use strict;
use warnings;

use Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(tag);

# support for ANSI color output via colored()
use Term::ANSIColor;

# Quiet "Name "main::LINTIAN_ROOT" used only once"
# The variables comes from 'lintian'
() = ($main::verbose, $main::debug);

# configuration variables and defaults
our $verbose = $::verbose;
our $debug = $::debug;
our $show_info = 0;
our $show_experimental = 0;
our $show_overrides = 0;
our $output_formatter = \&print_tag;
our $min_severity = 1;
our $max_severity = 99;
our $min_significance = 1;
our $max_significance = 99;
our $color = 'never';

# The master hash with all tag info. Key is the tag name, value another hash
# with the following keys:
# - tag: short name
# - type: error/warning/info/experimental
# - info: Description in HTML
# - ref: Any references
# - experimental: experimental status (possibly undef)
my %tags;

# Statistics per file. Key is the filename, value another hash with the
# following keys:
# - overrides
# - tags
# - severity
# - significance
my %stats;

# Info about a specific file. Key is the the filename, value another hash
# with the following keys:
# - pkg: package name
# - version: package version
# - arch: package architecture
# - type: one of 'binary', 'udeb' or 'source'
# - overrides: hash with all overrides for this file as keys
my %info;

# Currently selected file (not package!)
my $current;

# Compatibility stuff
my %codes = ( 'error' => 'E' , 'warning' => 'W' , 'info' => 'I' );
our %type_to_sev = ( error => 4, warning => 2, info => 0 );
our @sev_to_type = qw( info warning warning error error );

my @sig_to_qualifier = ( '??', '?', '', '!' );
my @sev_to_code = qw( I W W E E );
my @sev_to_color = ( 'cyan', 'yellow', 'yellow', 'red', 'red' );

# Add a new tag, supplied as a hash reference
sub add_tag {
	my $newtag = shift;
	if (exists $tags{$newtag->{tag}}) {
	    warn "Duplicate tag: $newtag->{tag}\n";
	    return 0;
	}

	# smooth transition
	$newtag->{type} = $sev_to_type[$newtag->{severity}]
	    unless $newtag->{type};
	$newtag->{significance} = 2 unless exists $newtag->{significance};
	$newtag->{severity} = $type_to_sev{$newtag->{type}}
	    unless exists $newtag->{severity};
	$tags{$newtag->{'tag'}} = $newtag;
	return 1;
}

# Add another file, will fail if there is already stored info about
# the file
sub set_pkg {
    my ( $file, $pkg, $version, $arch, $type ) = @_;

    if (exists $info{$file}) {
	warn "File $file was already processed earlier\n";
	return 0;
    }

    $current = $file;
    $info{$file} = {
	pkg => $pkg,
	version => $version,
	arch => $arch,
	type => $type,
	overrides => {},
    };
    $stats{$file} = {
	severity => {},
	significance => {},
	tags => {},
	overrides => {},
    };

    return 1;
}

# select another file as 'current' without deleting or adding any information
# the file must have been added with add_pkg
sub select_pkg {
    my ( $file ) = @_;

    unless (exists $info{$file}) {
	warn "Can't select package $file";
	return 0;
    }

    $current = $file;
    return 1;
}

# only delete the value of 'current' without deleting any stored information
sub reset_pkg {
    undef $current;
    return 1;
}

# delete all the stored information (including tags)
sub reset {
    undef %stats;
    undef %info;
    undef %tags;
    undef $current;
    return 1;
}

# Add an override. If you specifiy two arguments, the first will be taken
# as file to add the override to, otherwise 'current' will be assumed
sub add_override {
    my ($tag, $file) = ( "", "" );
    if (@_ > 1) {
	($file, $tag) = @_;
    } else {
	($file, $tag) = ($current, @_);
    }

    unless ($file) {
	warn "Don't know which package to add override $tag to";
	return 0;
    }

    $info{$file}{overrides}{$tag} = 0;

    return 1;
}

sub get_overrides {
    my ($file) = @_;

    unless ($file) {
	warn "Don't know which package to get overrides from";
	return undef;
    }

    return $info{$file}{overrides};
}

# Get the info hash for a tag back as a reference. The hash will be
# copied first so that you can edit it safely
sub get_tag_info {
    my ( $tag ) = @_;
    return { %{$tags{$tag}} } if exists $tags{$tag};
    return undef;
}

sub check_range {
    my ( $x, $min, $max ) = @_;

    return -1 if $x < $min;
    return 1 if $x > $max;
    return 0;
}

# check if a certain tag has a override for the 'current' package
sub check_overrides {
    my ( $tag_info, $information ) = @_;

    my $extra = '';
    $extra = " @$information" if @$information;
    $extra = '' if $extra eq ' ';
    if( exists $info{$current}{overrides}{$tag_info->{tag}}) {
	$info{$current}{overrides}{$tag_info->{tag}}++;
	return $tag_info->{tag};
    } elsif( exists $info{$current}{overrides}{"$tag_info->{tag}$extra"} ) {
	$info{$current}{overrides}{"$tag_info->{tag}$extra"}++;
	return "$tag_info->{tag}$extra";
    }

    return '';
}

# sets all the overridden fields of a tag_info hash correctly
sub check_need_to_show {
    my ( $tag_info, $information ) = @_;
    $tag_info->{overridden}{override} = check_overrides( $tag_info,
							 $information );
    my $min_sev = $show_info ? 0 : $min_severity; # compat hack
    $tag_info->{overridden}{severity} = check_range( $tag_info->{severity},
						     $min_sev,
						     $max_severity );
    $tag_info->{overridden}{significance} = check_range( $tag_info->{significance},
							 $min_significance,
							 $max_significance );
}

# records the stats for a given tag_info hash
sub record_stats {
    my ( $tag_info ) = @_;

    for my $k (qw( severity significance tag )) {
	$stats{$current}{$k}{$tag_info->{$k}}++
	    unless $tag_info->{overridden}{override}
		|| $tag_info->{overridden}{severity}
		|| $tag_info->{overridden}{significance};
    }
    for my $k (qw( severity significance override )) {
	$stats{$current}{overrides}{$k}{$tag_info->{overridden}{$k}}++
	    if $tag_info->{overridden}{$k};
    }
    if ($tag_info->{overridden}{override}) {
        $stats{$current}{overrides}{by_severity}{$tag_info->{severity}}++;
    }
}

# get the statistics for a file (one argument) or for all files (no argument)
sub get_stats {
    my ( $file ) = @_;

    return $stats{$file} if $file;
    return \%stats;
}

# Color tags with HTML.  Takes the tag and the color name.
sub colored_html {
    my ($tag, $color) = @_;
    return qq(<span style="color: $color">$tag</span>);
}

sub print_tag {
    my ( $pkg_info, $tag_info, $information ) = @_;

    my $extra = '';
    $extra = " @$information" if @$information;
    $extra = '' if $extra eq ' ';
    my $code = $codes{$tag_info->{type}};
    my $severity = $type_to_sev{$tag_info->{type}};
    $code = 'X' if exists $tag_info->{experimental};
    $code = 'O' if $tag_info->{overridden}{override};
    my $type = '';
    $type = " $pkg_info->{type}" if $pkg_info->{type} ne 'binary';

    my $output = "$code: $pkg_info->{pkg}$type: ";
    if ($color eq 'always' || ($color eq 'auto' && -t STDOUT)) {
        $output .= colored($tag_info->{tag}, $sev_to_color[$severity]);
    } elsif ($color eq 'html') {
        $output .= colored_html($tag_info->{tag}, $sev_to_color[$severity]);
    } else {
        $output .= $tag_info->{tag};
    }
    $output .= "$extra\n";

    print $output;
}

sub print_tag_new {
    my ( $pkg_info, $tag_info, $information ) = @_;

    my $extra = '';
    $extra = " @$information" if @$information;
    $extra = '' if $extra eq ' ';
    my $code = $sev_to_code[$tag_info->{severity}];
    $code = 'X' if exists $tag_info->{experimental};
    $code = 'O' if $tag_info->{overridden}{override};
    my $qualifier = $sig_to_qualifier[$tag_info->{significance}];
    $qualifier = '' if $code eq 'O';
    my $type = '';
    $type = " $pkg_info->{type}" if $pkg_info->{type} ne 'binary';

    my $output = "$code$qualifier: $pkg_info->{pkg}$type: ";
    if ($color eq 'always' || ($color eq 'auto' && -t STDOUT)) {
        $output .= colored($tag_info->{tag}, $sev_to_color[$tag_info->{severity}]);
    } else {
        $output .= $tag_info->{tag};
    }
    $output .= "$extra\n";

    print $output;

}

sub tag {
    my ( $tag, @information ) = @_;
    unless ($current) {
	warn "Tried to issue tag $tag without setting package\n";
	return 0;
    }

    # Newlines in @information would cause problems, so replace them with \n.
    @information = map { s,\n,\\n,; $_ } @information;

    my $tag_info = get_tag_info( $tag );
    unless ($tag_info) {
	warn "Tried to issue unknown tag $tag\n";
	return 0;
    }
    check_need_to_show( $tag_info, \@information );

    record_stats( $tag_info );

    return 0 if
	exists $tag_info->{experimental} and !$show_experimental;

    return 1 if
	$tag_info->{overridden}{severity} != 0
	|| $tag_info->{overridden}{significance} != 0
	|| ( $tag_info->{overridden}{override} &&
	     !$show_overrides);

    &$output_formatter( $info{$current}, $tag_info, \@information );
    return 1;
}

1;

# Local Variables:
# indent-tabs-mode: t
# cperl-indent-level: 4
# End:
# vim: ts=4 sw=4 noet

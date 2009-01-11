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

use Lintian::Output;

# configuration variables and defaults
our $show_experimental = 0;
our $show_overrides = 0;
our %display_level;
our %display_source;
our %only_issue_tags;

# The master hash with all tag info. Key is the tag name, value another hash
# with the following keys:
# - tag: short name
# - info: Description in HTML
# - ref: Any references
# - experimental: experimental status (possibly undef)
my %tags;

# Statistics per file. Key is the filename, value another hash with the
# following keys:
# - overrides
# - tags
# - types
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

# Possible Severity: and Certainty: values, sorted from lowest to highest.
our @severity_list = qw(wishlist minor normal important serious);
our @certainty_list = qw(wild-guess possible certain);

# Map Severity/Certainty levels to E|W|I codes.
my %codes = (
    'wishlist'  => { 'wild-guess' => 'I', 'possible' => 'I', 'certain' => 'I' },
    'minor'     => { 'wild-guess' => 'I', 'possible' => 'I', 'certain' => 'W' },
    'normal'    => { 'wild-guess' => 'I', 'possible' => 'W', 'certain' => 'W' },
    'important' => { 'wild-guess' => 'W', 'possible' => 'E', 'certain' => 'E' },
    'serious'   => { 'wild-guess' => 'E', 'possible' => 'E', 'certain' => 'E' },
);

# Add a new tag, supplied as a hash reference
sub add_tag {
	my $newtag = shift;
	if (exists $tags{$newtag->{tag}}) {
	    warn "Duplicate tag: $newtag->{tag}\n";
	    return 0;
	}

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

    $info{$file} = {
	file => $file,
	pkg => $pkg,
	version => $version,
	arch => $arch,
	type => $type,
	overrides => {},
    };
    $stats{$file} = {
	types => {},
	tags => {},
	overrides => {},
    };

    select_pkg($file);
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

    if ($current) {
	$Lintian::Output::GLOBAL->print_end_pkg($info{$current});
    }
    $current = $file;
    if ($file !~ /.changes$/) {
	$Lintian::Output::GLOBAL->print_start_pkg($info{$current});
    }
    return 1;
}

# only delete the value of 'current' without deleting any stored information
sub reset_pkg {
    if ($current) {
	$Lintian::Output::GLOBAL->print_end_pkg($info{$current});
    }
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
    my ($tag, $extra, $file) = ( "", "", "" );
    if (@_ > 2) {
	($file, $tag, $extra) = @_;
    } else {
	($file, $tag, $extra) = ($current, @_);
    }
    $extra ||= "";

    unless ($file) {
	warn "Don't know which package to add override $tag to";
	return 0;
    }

    $info{$file}{overrides}{$tag}{$extra} = 0;

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

# Returns the E|W|I code for a given tag.
sub get_tag_code {
    my ( $tag_info ) = @_;
    return $codes{$tag_info->{severity}}{$tag_info->{certainty}};
}

# check if a certain tag has a override for the 'current' package
sub check_overrides {
    my ( $tag_info, $information ) = @_;

    my $tag = $tag_info->{tag};
    my $overrides = $info{$current}{overrides}{$tag};
    return unless $overrides;

    if( exists $overrides->{''} ) {
	$overrides->{''}++;
	return $tag;
    } elsif( $information ne '' and exists $overrides->{$information} ) {
	$overrides->{$information}++;
	return "$tag $information";
    } elsif ( $information ne '' ) {
	foreach (keys %$overrides) {
	    my $regex = $_;
	    if (m/^\*/ or m/\*$/) {
		my ($start, $end) = ("","");
		$start = '.*' if $regex =~ s/^\*//;
		$end   = '.*' if $regex =~ s/\*$//;
		if ($information =~ /^$start\Q$regex\E$end$/) {
		    $overrides->{$_}++;
		    return "$tag $_";
		}
	    }
	}
    }

    return '';
}

# sets all the overridden fields of a tag_info hash correctly
sub set_overrides {
    my ( $tag_info, $information ) = @_;
    $tag_info->{overridden}{override} = check_overrides( $tag_info,
							 $information );
}

# records the stats for a given tag_info hash
sub record_stats {
    my ( $tag_info ) = @_;

    if ($tag_info->{overridden}{override}) {
	$stats{$current}{overrides}{tags}{$tag_info->{overridden}{override}}++;
	$stats{$current}{overrides}{severity}{$tag_info->{severity}}++;
	$stats{$current}{overrides}{certainty}{$tag_info->{certainty}}++;
	$stats{$current}{overrides}{types}{get_tag_code($tag_info)}++;
    } else {
	$stats{$current}{tags}{$tag_info->{tag}}++;
	$stats{$current}{severity}{$tag_info->{severity}}++;
	$stats{$current}{certainty}{$tag_info->{certainty}}++;
	$stats{$current}{types}{get_tag_code($tag_info)}++;
    }
}

# get the statistics for a file (one argument) or for all files (no argument)
sub get_stats {
    my ( $file ) = @_;

    return $stats{$file} if $file;
    return \%stats;
}

# Extract manual sources from a given tag. Returns a hash that has manual
# names as keys and sections/ids has values.
sub get_tag_source {
    my ( $tag_info ) = @_;
    my $ref = $tag_info->{'ref'};
    return undef if not $ref;

    my @refs = split(',', $ref);
    my %source = ();
    foreach my $r (@refs) {
        $source{$1} = $2 if $r =~ /^([\w-]+)\s(.+)$/;
    }
    return \%source;
}

# Checks if the Severity/Certainty level of a given tag passes the threshold
# of requested tags (returns 1) or not (returns 0). If there are restrictions
# by source, references will be also checked. The result is also saved in the
# tag structure to avoid unnecessarily checking later.
sub display_tag {
    my ( $tag_info ) = @_;
    return $tag_info->{'display'} if defined $tag_info->{'display'};

    my $severity = $tag_info->{'severity'};
    my $certainty = $tag_info->{'certainty'};
    my $level;
    if ($severity and $certainty) {
	$level = $display_level{$severity}{$certainty};
    } else {
	# Shouldn't happen, but avoid Perl warnings anyway.
	$level = 1;
    }

    $tag_info->{'display'} = $level;
    return $level if not keys %display_source;

    my $tag_source = get_tag_source($tag_info);
    my %in = map { $_ => 1 } grep { $tag_source->{$_} } keys %display_source;

    $tag_info->{'display'} = ($level and keys %in) ? 1 : 0;
    return $tag_info->{'display'};
}

sub skip_print {
    my ( $tag_info ) = @_;
    return 1 if exists $tag_info->{experimental} && !$show_experimental;
    return 1 if $tag_info->{overridden}{override} && !$show_overrides;
    return 1 if not display_tag( $tag_info );
    return 0;
}

sub tag {
    my ( $tag, @information ) = @_;
    unless ($current) {
	warn "Tried to issue tag $tag without setting package\n";
	return 0;
    }

    return 0 unless
	! keys %only_issue_tags or exists $only_issue_tags{$tag};

    # Clean up @information and collapse it to a string.  Lintian code doesn't
    # treat the distinction between extra arguments to tag() as significant,
    # so we may as well take care of this up front.
    @information = grep { defined($_) and $_ ne '' }
	map { s,\n,\\n,; $_ } @information;
    my $information = join(' ', @information);
    $information = '' unless defined $information;

    my $tag_info = get_tag_info( $tag );
    unless ($tag_info) {
	warn "Tried to issue unknown tag $tag\n";
	return 0;
    }

    set_overrides( $tag_info, $information );

    record_stats( $tag_info );

    return 1 if skip_print( $tag_info );

    $Lintian::Output::GLOBAL->print_tag( $info{$current}, $tag_info,
					 $information );
    return 1;
}

1;

# Local Variables:
# indent-tabs-mode: t
# cperl-indent-level: 4
# End:
# vim: ts=4 sw=4 noet

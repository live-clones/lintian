# Hey emacs! This is a -*- Perl -*- script!
# Read_pkglists -- Perl utility functions to read Lintian's package lists

# Copyright (C) 1998 Christian Schwarz
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
# Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
# MA 02111-1307, USA.

use strict;
use vars qw($BINLIST_FORMAT $SRCLIST_FORMAT $UDEBLIST_FORMAT %source_info %binary_info %udeb_info %bin_src_ref);

# these banner lines have to be changed with every incompatible change of the
# binary and source list file formats
$BINLIST_FORMAT = "Lintian's list of binary packages in the archive--V2";
$SRCLIST_FORMAT = "Lintian's list of source packages in the archive--V2";
$UDEBLIST_FORMAT = "Lintian's list of udeb packages in the archive--V1";

%source_info = ();
%binary_info = ();
%udeb_info = ();
%bin_src_ref = ();

sub read_src_list {
  my ($src_list,$quiet) = @_;
  my $LINTIAN_LAB = $ENV{'LINTIAN_LAB'};

  if (%source_info) {
    warn "\%source_info exists, nothing to do in read_src_list\n" unless $quiet;
    return;
  }

  $src_list or ($src_list = "$LINTIAN_LAB/info/source-packages");
  return unless -s $src_list;

  open(IN,$src_list) or fail("cannot open source list file $src_list: $!");

  # compatible file format?
  my $f;
  chop($f = <IN>);
  if ($f ne $SRCLIST_FORMAT) {
    close(IN);
    return 0 if $quiet;
    fail("the source list file $src_list has an incompatible file format (run lintian --setup-lab)");
  }

  # compatible format, so read file
  while (<IN>) {
    chop;
    next if /^\s*$/o;
    my ($src,$ver,$maint,$arch,$std,$bin,$files,$file,$timestamp) = split(/\;/,$_);

    my $src_struct;
    %$src_struct =
      (
       'source' => $src,
       'version' => $ver,
       'maintainer' => $maint,
       'architecture' => $arch,
       'standards-version' => $std,
       'binary' => $bin,
       'files' => $files,
       'file' => $file,
       'timestamp' => $timestamp,
       );

    $source_info{$src} = $src_struct;
  }

  close(IN);
}

sub read_bin_list {
  my ($bin_list,$quiet) = @_;
  my $LINTIAN_LAB = $ENV{'LINTIAN_LAB'};

  if (%binary_info) {
    warn "\%binary_info exists, nothing to do in read_bin_list\n" unless $quiet;
    return;
  }

  $bin_list or ($bin_list = "$LINTIAN_LAB/info/binary-packages");
  return unless -s $bin_list;

  open(IN,$bin_list) or fail("cannot open binary list file $bin_list: $!");

  # compatible file format?
  my $f;
  chop($f = <IN>);
  if ($f ne $BINLIST_FORMAT) {
    close(IN);
    return 0 if $quiet;
    fail("the binary list file $bin_list has an incompatible file format (run lintian --setup-lab)");
  }

  # compatible format, so read file
  while (<IN>) {
    chop;

    next if /^\s*$/o;
    my ($bin,$ver,$source,$file,$timestamp) = split(/\;/o,$_);

    my $bin_struct;
    %$bin_struct =
      (
       'package' => $bin,
       'version' => $ver,
       'source' => $source,
       'file' => $file,
       'timestamp' => $timestamp,
       );

    $binary_info{$bin} = $bin_struct;
  }

  close(IN);
}

sub read_udeb_list {
  my ($udeb_list,$quiet) = @_;
  my $LINTIAN_LAB = $ENV{'LINTIAN_LAB'};

  if (%udeb_info) {
    warn "\%udeb_info exists, nothing to do in read_bin_list\n" unless $quiet;
    return;
  }

  $udeb_list or ($udeb_list = "$LINTIAN_LAB/info/udeb-packages");
  return unless -s $udeb_list;

  open(IN,$udeb_list) or fail("cannot open udeb list file $udeb_list: $!");

  # compatible file format?
  my $f;
  chop($f = <IN>);
  if ($f ne $UDEBLIST_FORMAT) {
    close(IN);
    return 0 if $quiet;
    fail("the udeb list file $udeb_list has an incompatible file format (run lintian --setup-lab)");
  }

  # compatible format, so read file
  while (<IN>) {
    chop;

    next if /^\s*$/o;
    my ($udeb,$ver,$source,$file,$timestamp) = split(/\;/o,$_);

    my $udeb_struct;
    %$udeb_struct =
      (
       'package' => $udeb,
       'version' => $ver,
       'source' => $source,
       'file' => $file,
       'timestamp' => $timestamp,
       );

    $udeb_info{$udeb} = $udeb_struct;
  }

  close(IN);
}



sub get_bin_src_ref {
  read_src_list();
  for my $source (keys %source_info) {
    for my $binary (split(/,\s+/o,$source_info{$source}->{'binary'})) {
      $bin_src_ref{$binary} = $source;
    }
  }
}

1;

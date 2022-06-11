# files/artifact -- lintian check script -*- perl -*-
#
# based on debhelper check,
# Copyright (C) 1999 Joey Hess
# Copyright (C) 2000 Sean 'Shaleh' Perry
# Copyright (C) 2002 Josip Rodin
# Copyright (C) 2007 Russ Allbery
# Copyright (C) 2013-2018 Bastien ROUCARIÈS
# Copyright (C) 2017-2020 Chris Lamb <lamby@debian.org>
# Copyright (C) 2020-2021 Felix Lechner
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

package Lintian::Check::Files::Artifact;

use v5.20;
use warnings;
use utf8;

use List::SomeUtils qw(first_value);

use Moo;
use namespace::clean;

with 'Lintian::Check';

# Directory checks.  These regexes match a directory that shouldn't be in the
# source package and associate it with a tag (minus the leading
# source-contains or debian-adds).  Note that only one of these regexes
# should trigger for any single directory.
my @directory_checks = (
    [qr{^(.+/)?CVS/?$}        => 'cvs-control-dir'],
    [qr{^(.+/)?\.svn/?$}      => 'svn-control-dir'],
    [qr{^(.+/)?\.bzr/?$}      => 'bzr-control-dir'],
    [qr{^(.+/)?\{arch\}/?$}   => 'arch-control-dir'],
    [qr{^(.+/)?\.arch-ids/?$} => 'arch-control-dir'],
    [qr{^(.+/)?,,.+/?$}       => 'arch-control-dir'],
    [qr{^(.+/)?\.git/?$}      => 'git-control-dir'],
    [qr{^(.+/)?\.hg/?$}       => 'hg-control-dir'],
    [qr{^(.+/)?\.be/?$}       => 'bts-control-dir'],
    [qr{^(.+/)?\.ditrack/?$}  => 'bts-control-dir'],

    # Special case (can only be triggered for diffs)
    [qr{^(.+/)?\.pc/?$} => 'quilt-control-dir'],
);

# File checks.  These regexes match files that shouldn't be in the source
# package and associate them with a tag (minus the leading source-contains or
# debian-adds).  Note that only one of these regexes should trigger for any
# given file.
my @file_checks = (
    [qr{^(.+/)?svn-commit\.(.+\.)?tmp$} => 'svn-commit-file'],
    [qr{^(.+/)?svk-commit.+\.tmp$}      => 'svk-commit-file'],
    [qr{^(.+/)?\.arch-inventory$}       => 'arch-inventory-file'],
    [qr{^(.+/)?\.hgtags$}               => 'hg-tags-file'],
    [qr{^(.+/)?\.\#(.+?)\.\d+(\.\d+)*$} => 'cvs-conflict-copy'],
    [qr{^(.+/)?(.+?)\.(r[1-9]\d*)$}     => 'svn-conflict-file'],
    [qr{\.(orig|rej)$}                  => 'patch-failure-file'],
    [qr{((^|/)[^/]+\.swp|~)$}           => 'editor-backup-file'],
);

sub source {
    my ($self) = @_;

    my @added_by_debian;
    my $prefix;
    if ($self->processable->native) {

        @added_by_debian = @{$self->processable->patched->sorted_list};
        $prefix = 'source-contains';

    } else {
        my $patched = $self->processable->patched;
        my $orig = $self->processable->orig;

        @added_by_debian
          = grep { !defined $orig->lookup($_->name) } @{$patched->sorted_list};

        # remove root quilt control folder and all paths in it
        # created when 3.0 (quilt) source packages are unpacked
        @added_by_debian = grep { $_->name !~ m{^.pc/} } @added_by_debian
          if $self->processable->source_format eq '3.0 (quilt)';

        my @common_items
          = grep { defined $orig->lookup($_->name) } @{$patched->sorted_list};
        my @touched_by_debian
          = grep { $_->md5sum ne $orig->lookup($_->name)->md5sum }
          @common_items;

        $self->hint('no-debian-changes')
          unless @added_by_debian || @touched_by_debian;

        $prefix = 'debian-adds';
    }

    # ignore lintian test set; should use automatic loop in the future
    @added_by_debian = grep { $_->name !~ m{^t/} } @added_by_debian
      if $self->processable->source_name eq 'lintian';

    my @directories = grep { $_->is_dir } @added_by_debian;
    for my $directory (@directories) {

        my $rule = first_value { $directory->name =~ /$_->[0]/s }
        @directory_checks;
        $self->pointed_hint("${prefix}-$rule->[1]", $directory->pointer)
          if defined $rule;
    }

    my @files = grep { $_->is_file } @added_by_debian;
    for my $item (@files) {

        my $rule = first_value { $item->name =~ /$_->[0]/s } @file_checks;
        $self->pointed_hint("${prefix}-$rule->[1]", $item->pointer)
          if defined $rule;
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

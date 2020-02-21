# -*- perl -*-
# Lintian::Processable::Package -- interface to data collection for packages

# Copyright (C) 2011 Niels Thykier
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::Processable::Package;

use strict;
use warnings;
use autodie;

use BerkeleyDB;
use Carp qw(croak);
use Path::Tiny;
use Scalar::Util qw(blessed);

use Lintian::File::Path;
use Lintian::Path::FSInfo;
use Lintian::Util
  qw(internal_error open_gz perm2oct normalize_pkg_path dequote_name);

use Moo::Role;
use namespace::clean;

with 'Lintian::Processable::Checksums::Md5', 'Lintian::Processable::FileInfo',
  'Lintian::Processable::Java', 'Lintian::Processable::Scripts::Control';

# A cache for (probably) the 5 most common permission strings seen in
# the wild.
# It may seem obscene, but it has an extreme "hit-ratio" and it is
# cheaper vastly than perm2oct.
my %PERM_CACHE = map { $_ => perm2oct($_) } (
    '-rw-r--r--', # standard (non-executable) file
    '-rwxr-xr-x', # standard executable file
    'drwxr-xr-x', # standard dir perm
    'drwxr-sr-x', # standard dir perm with suid (lintian-lab on lintian.d.o)
    'lrwxrwxrwx', # symlinks
);

my %FILE_CODE2LPATH_TYPE = (
    '-' => Lintian::File::Path::TYPE_FILE| Lintian::File::Path::OPEN_IS_OK,
    'h' => Lintian::File::Path::TYPE_HARDLINK| Lintian::File::Path::OPEN_IS_OK,
    'd' => Lintian::File::Path::TYPE_DIR| Lintian::File::Path::FS_PATH_IS_OK,
    'l' => Lintian::File::Path::TYPE_SYMLINK,
    'b' => Lintian::File::Path::TYPE_BLOCK_DEV,
    'c' => Lintian::File::Path::TYPE_CHAR_DEV,
    'p' => Lintian::File::Path::TYPE_PIPE,
);

=head1 NAME

Lintian::Processable::Package - Lintian base interface to binary and source package data collection

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Processable::Package provides an interface to package data for
source and binary packages.  It implements data collection methods
specific to packages that can be unpacked (or can contain files)

=head1 INSTANCE METHODS

=over 4

=cut

# Backing method for unpacked, debfiles and others; this is not a part of the
# API.
# sub _fetch_extracted_dir Needs-Info none
sub _fetch_extracted_dir {
    my ($self, $field, $dirname, $file) = @_;
    my $dir = $self->{$field};
    my $filename = '';
    my $normalized = 0;
    if (not defined $dir) {
        $dir = path($self->groupdir)->child($dirname)->stringify;
        croak "$field ($dirname) is not available" unless -d "$dir/";
        $self->{$field} = $dir;
    }

    if (!defined($file)) {
        if (scalar(@_) >= 4) {
            # Was this undef explicit?
            croak('Input file was undef');
        }
        $normalized = 1;
    } else {
        if (ref($file)) {
            if (!blessed($file) || !$file->isa('Lintian::File::Path')) {
                croak(
'Input file must be a string or a Lintian::File::Path object'
                );
            }
            $filename = $file->name;
            $normalized = 1;
        } else {
            $normalized = 0;
            $filename = $file;
        }
    }

    if ($filename ne '') {
        if (!$normalized) {
            # strip leading ./ - if that leaves something, return the
            # path there
            if ($filename =~ s,^(?:\.?/)++,,go) {
                warnings::warnif('Lintian::Collect',
                    qq{Argument to $field had leading "/" or "./"});
            }
            if ($filename =~ m{(?: ^|/ ) \.\. (?: /|$ )}xsm) {
                # possible traversal - double check it and (if needed)
                # stop it before it gets out of hand.
                if (!defined(normalize_pkg_path('/', $filename))) {
                    croak qq{The path "$file" is not within the package root};
                }
            }
        }
        return "$dir/$filename" if $filename ne '';
    }
    return $dir;
}

# Internal sub for providing a shared storage between multiple
# L::Collect objects from same group.
#

# Internal sub for dumping the memory usage of this instance
#
# Used by the frontend (under debug level >= 4)
#
# sub _memory_usage Needs-Info none
sub _memory_usage {
    my ($self, $calc_usage) = @_;

    my %usage;

    for my $field (keys %{$self}) {

        next
          if ($field =~ m{ \A sorted_ }xsm);

        if (exists($self->{"sorted_$field"})) {
            # merge "index" and "sorted_index".  At the price of an extra
            # list, we avoid overcounting all the L::Path objects so the
            # produced result is a lot more accurate.
            $usage{$field}
              = $calc_usage->([$self->{$field},$self->{"sorted_$field"}]);

        } else {
            $usage{$field} = $calc_usage->($self->{$field});
        }
    }

    return \%usage;
}

1;

=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.

=head1 SEE ALSO

lintian(1), L<Lintian::Collect>, L<Lintian::Collect::Binary>,
L<Lintian::Collect::Source>

=cut

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

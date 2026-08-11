# -*- perl -*- Lintian::Storage::PerMember
#
# Derived from former Lintian::Storage::MLDBM module with:
# Copyright (C) 2022 Felix Lechner
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

package Lintian::Storage::PerMember;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Digest::MD5 qw(md5_hex);
use File::Temp;
use Path::Tiny;
use Storable qw(freeze thaw);
use Syntax::Keyword::Try;
use Unicode::UTF8 qw(encode_utf8);

const my $EMPTY => q{};
const my $HYPHEN => q{-};

=head1 NAME

Lintian::Storage::PerMember - store multi-level hashes on disk

=head1 SYNOPSIS

    use Lintian::Storage::PerMember;

    my $storage = Lintian::Storage::PerMember->create('elf');
    my $name = 'usr/bin/true';
    $storage->{$name} = { NEEDED => ['libc.so.6'] };
    my $info = $storage->{$name};

=head1 DESCRIPTION

Lintian::Storage::PerMember provides an interface to store data on disk to
preserve memory. Each hash key corresponds to a separate Storable file in a
temporary directory, so values are only in memory while they are being read
or written.

=head1 CLASS METHODS

=over 4

=item create

Creates a temporary directory and returns a hash tied to it. Each assigned
key is stored in its own file there.

=cut

sub create {
    my ($class, $description) = @_;

    $description //= $EMPTY;

    $description .= $HYPHEN
      if length $description;

    my $stem = "per-member-$description";

    my $directory
      = File::Temp->newdir($stem . 'XXXX', TMPDIR => 1, CLEANUP => 1);

    my $hash = {};

    tie %{$hash}, $class, $directory;

    return $hash;
}

=back

=head1 INSTANCE METHODS

=over 4

=item TIEHASH

=cut

sub TIEHASH {
    my ($class, $directory) = @_;

    return bless {
        directory => Path::Tiny->new("$directory"),
        tempdir   => $directory
      },
      $class;
}

=item STORE

=cut

sub STORE {
    my ($self, $key, $value) = @_;

    my $file = $self->_file($key);

    try {
        $file->spew_raw(freeze([$key, $value]));

    } catch {
        die encode_utf8("Cannot store value for $key in $file: $@");
    }

    return;
}

=item FETCH

=cut

sub FETCH {
    my ($self, $key) = @_;

    my $file = $self->_file($key);

    return undef
      unless $file->is_file;

    my $value;

    try {
        $value = thaw($file->slurp_raw)->[1];

    } catch {
        die encode_utf8("Cannot read value for $key in $file: $@");
    }

    return $value;
}

=item EXISTS

=cut

sub EXISTS {
    my ($self, $key) = @_;

    return $self->_file($key)->is_file;
}

=item DELETE

=cut

sub DELETE {
    my ($self, $key) = @_;

    my $file = $self->_file($key);

    return undef
      unless $file->is_file;

    my $value;

    try {
        $value = thaw($file->slurp_raw)->[1];
        $file->remove;

    } catch {
        die encode_utf8("Cannot delete value for $key in $file: $@");
    }

    return $value;
}

=item CLEAR

=cut

sub CLEAR {
    my ($self) = @_;

    for my $file ($self->{directory}->children) {

        $file->remove
          if $file->is_file;
    }

    return;
}

=item FIRSTKEY

=cut

sub FIRSTKEY {
    my ($self) = @_;

    my @keys = sort map { thaw($_->slurp_raw)->[0] }
      grep { $_->is_file } $self->{directory}->children;

    $self->{keys} = \@keys;
    $self->{keys_index} = 0;

    return $self->NEXTKEY(undef);
}

=item NEXTKEY

=cut

sub NEXTKEY {
    my ($self, $lastkey) = @_;

    my $index = $self->{keys_index}++;

    return $self->{keys}[$index];
}

=item DESTROY

Removes the temporary directory when the tied hash goes out of scope.

=cut

sub DESTROY {
    my ($self) = @_;

    return
      if ${^GLOBAL_PHASE} eq 'DESTRUCT';

    try {
        $self->{directory}->remove_tree;

    } catch {
        # Directory will be removed again on program exit (File::Temp)
    }

    return;
}

=item _file

Returns the file associated with the given key.

=cut

sub _file {
    my ($self, $key) = @_;

    return $self->{directory}->child(md5_hex($key));
}

=back

=head1 SEE ALSO

lintian(1)

=cut

1;

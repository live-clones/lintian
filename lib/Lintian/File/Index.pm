# -*- perl -*- Lintian::File::Index
#
# Copyright © 2020 Felix Lechner
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

package Lintian::File::Index;

use strict;
use warnings;
use autodie;

use Carp;
use BerkeleyDB;
use List::MoreUtils qw(any);
use MLDBM qw(BerkeleyDB::Btree Storable);
use Path::Tiny;
use Scalar::Util qw(blessed);

use Lintian::File::Path;
use Lintian::Util qw(open_gz perm2oct dequote_name);

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant SLASH => q{/};

use Moo;
use namespace::clean;

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

Lintian::File::Index - access to collected data about the upstream (orig) sources

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Processable::Orig::Index provides an interface to collected data about the upstream (orig) sources.

=head1 INSTANCE METHODS

=over 4

=item index

Returns a reference to a hash with elements indexed by path names.

=item saved_sorted_list

Returns a reference to a sorted array with path names.

=item C<basedir>

Returns the base directory for file references.

=item C<anchored>

=item C<allow_empty>

=item C<fileinfo_sub>

=cut

has index => (is => 'rw', default => sub { {} });
has saved_sorted_list => (is => 'rw', default => sub { [] });
has basedir => (is => 'rw', default => EMPTY);
has anchored => (is => 'rw', default => 0);
has allow_empty => (is => 'rw', default => 0);
has fileinfo_sub => (is => 'rw');

=item sorted_list

Like L<sorted_index|Lintian::Collect/sorted_index> except
sorted_orig_index is based on the "orig tarballs" of the source
packages.

For native packages L<sorted_index|Lintian::Collect/sorted_index> and
L</sorted_orig_index> are generally identical.

NB: If sorted_orig_index includes a debian packaging, it is was
contained in upstream part of the source package (or the package is
native).

Needs-Info requirements for using I<sorted_orig_index>: L<Same as orig_index|/orig_index ([FILE])>

=cut

sub sorted_list {
    my ($self) = @_;

    unless (scalar @{ $self->saved_sorted_list }) {

        my @names = sort keys %{$self->index};
        my @sorted = map { $self->index->{$_} } @names;

        # remove automatic root dir; list is sorted
        shift @sorted;

        $self->saved_sorted_list(\@sorted);
    }

    return @{ $self->saved_sorted_list };
}

=item lookup (FILE)

Like L</index> except orig_index is based on the "orig tarballs" of
the source packages.

For native packages L</index> and L</orig_index> are generally
identical.

NB: If sorted_index includes a debian packaging, it is was
contained in upstream part of the source package (or the package is
native).

Needs-Info requirements for using I<orig_index>: src-orig-index

=cut

sub lookup {
    my ($self, $name) = @_;

    # get root dir by default
    $name //= EMPTY;

    croak 'Name is not a string'
      unless ref $name eq EMPTY;

    return $self->index->{$name}
      if exists $self->index->{$name};

    return;
}

=item resolve_path

=cut

sub resolve_path {
    my ($self, $name) = @_;

    return $self->lookup->resolve_path($name);
}

=item load

=cut

sub load {
    my ($self, $dbpath) = @_;

    return {}
      unless -f $dbpath;

    tie my %h, 'MLDBM',-Filename => $dbpath
      or die "Cannot open file $dbpath: $! $BerkeleyDB::Error\n";

    my %all;
    $all{$_} = $h{$_} for keys %h;

    untie %h;

    # set internal permissions flags
    for my $entry (values %all) {

        my $raw_type = substr($entry->perm, 0, 1);

        my $operm = perm2oct($entry->perm);
        $entry->path_info(
            $operm | (
                $FILE_CODE2LPATH_TYPE{$raw_type}
                  // Lintian::File::Path::TYPE_OTHER
            ));
    }

    # find all entries that are not regular files
    my @nosize
      = grep { !$_->path_info & Lintian::File::Path::TYPE_FILE } values %all;

    # reset size for anything but regular files
    $_->size(0) for @nosize;

    # add entries for missing directories
    for my $entry (values %all) {

        my $current = $entry;
        my $parentname;

        # travel up the directory tree
        do {
            $parentname = $current->parentname;

            # insert new entry for missing intermediate directories
            unless (exists $all{$parentname}) {

                my $added = Lintian::File::Path->new;
                $added->name($parentname);
                $added->path_info($FILE_CODE2LPATH_TYPE{'d'} | 0755);

                # random but fixed date; hint, it's a good read. :)
                $added->date('1998-01-25');
                $added->time('22:55:34');
                $added->faux(1);

                $all{$parentname} = $added;
            }

            $current = $all{$parentname};

        } while ($parentname ne EMPTY);
    }

    # all missing directories have been generated
    die 'The root dir should be present or have been faked'
      unless exists $all{''} || $self->allow_empty;

    # add base directory to all entries, including generated
    $_->basedir($self->basedir) for values %all;

    # add anchored parameter to all entries, including generated
    $_->anchored($self->anchored) for values %all;

    # add file info generator to all entries, including generated
    $_->fileinfo_sub($self->fileinfo_sub) for values %all;

    my @directories
      = grep { $_->path_info & Lintian::File::Path::TYPE_DIR } values %all;

    # make space for children
    my %children;
    $children{$_->name} = [] for @directories;

    # record children
    for my $entry (values %all) {

        my $parentname = $entry->parentname;

        # Ensure the "root" is not its own child.  It is not really helpful
        # from an analysis PoV and it creates ref cycles  (and by extension
        # leaks like #695866).
        push(@{ $children{$parentname} }, $entry)
          unless $parentname eq $entry->name;
    }

    # add in reverse; children are made before parent
    my @reverse = reverse sort { $a->name cmp $b->name } @directories;

    foreach my $entry (@reverse) {

        my @sorted_children = sort @{ $children{$entry->name}};
        $entry->sorted_children(\@sorted_children);

        my %child_table;
        $child_table{$_->basename} = $_ for @sorted_children;

        $entry->child_table(\%child_table);
        $_->_set_parent_dir($entry) for $entry->children;
    }

    # ensure root is not its own child; may create leaks like #695866
    die 'Root directory is its own parent'
      if any { $_ eq EMPTY } $all{''}->sorted_children;

    # find all hard links
    my @hardlinks
      = grep { $_->path_info & Lintian::File::Path::TYPE_HARDLINK }values %all;

    # catalog where they point
    my %backlinks;
    push(@{$backlinks{$_->link}}, $_) for @hardlinks;

    # add the master files for proper sort results
    push(@{$backlinks{$_}}, $all{$_}) for keys %backlinks;

    # point hard links to shortest path
    for my $mastername (keys %backlinks) {

        my @group = @{$backlinks{$mastername}};

        # sort for path length
        my @links = sort { $a->name cmp $b->name } @group;

        # pick the shortest path
        my $preferred = shift @links;

        # get the previous master entry
        my $master = $all{$mastername};

        # skip if done
        next
          if $preferred->name eq $master->name;

        # unset link for preferred
        $preferred->link(EMPTY);

        # copy size from original
        $preferred->size($master->size);

        $preferred->path_info(
            ($preferred->path_info& ~Lintian::File::Path::TYPE_HARDLINK)
            | Lintian::File::Path::TYPE_FILE);

        foreach my $pointer (@links) {

            # turn into a hard link
            $pointer->path_info(
                ($pointer->path_info & ~Lintian::File::Path::TYPE_FILE)
                | Lintian::File::Path::TYPE_HARDLINK);

            # set link to preferred path
            $pointer->link($preferred->name);

            # no size for hardlinks
            $pointer->size(0);
        }
    }

    # make sure recorded names match hash keys
    $all{$_}->name($_)for keys %all;

    $self->index(\%all);

    return;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1), L<Lintian::Collect>, L<Lintian::Collect::Binary>,
L<Lintian::Collect::Source>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

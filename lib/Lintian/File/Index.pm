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
use MLDBM qw(BerkeleyDB::Btree Storable);
use Path::Tiny;

use Lintian::File::Path;
use Lintian::Path::FSInfo;
use Lintian::Util qw(open_gz perm2oct dequote_name);

use constant EMPTY => q{};
use constant SPACE => q{ };

use Moo;
use namespace::clean;

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

my %INDEX_FAUX_DIR_TEMPLATE = (
    'name'       => '',
    'path_info' => $FILE_CODE2LPATH_TYPE{'d'} | 0755,
    # Pick a "random" (but fixed) date
    # - hint, it's a good read.  :)
    'date'       => '1998-01-25',
    'time'       => '22:55:34',
    'faux'       => 1,
);

=head1 NAME

Lintian::File::Index - access to collected data about the upstream (orig) sources

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Info::Orig::Index provides an interface to collected data about the upstream (orig) sources.

=head1 INSTANCE METHODS

=over 4

=item name

=item index

Returns a reference to a hash with elements indexed by path names.

=item saved_sorted_list

Returns a reference to a sorted array with path names.

=item C<basedir>

Returns the base directory for file references.

=item C<anchored>

=item C<allow_empty>

=item C<fs_root_sub>

=item C<file_info_sub>

=item C<fs_info>

=cut

has name => (is => 'rw', default => EMPTY);
has index => (is => 'rw', default => sub { {} });
has saved_sorted_list => (is => 'rw', default => sub { [] });
has basedir => (is => 'rw', default => EMPTY);
has anchored => (is => 'rw', default => 0);
has allow_empty => (is => 'rw', default => 0);
has fs_root_sub => (is => 'rw');
has file_info_sub => (is => 'rw');
has fs_info => (is => 'rw', default => sub { {} });

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
    my ($self) = @_;

    my $index = $self->name;
    my $allow_empty = $self->allow_empty;

    my $fs_info = Lintian::Path::FSInfo->new(
        '_collect_path_sub' => $self->fs_root_sub,
        '_collect_file_info_sub' => $self->file_info_sub,
        'has_anchored_root_dir' => $self->anchored,
    );
    $self->fs_info($fs_info);

    my %all;

    my $dbpath = path($self->basedir)->child("$index.db")->stringify;

    return {}
      unless -f $dbpath;

    tie my %h, 'MLDBM',-Filename => $dbpath
      or die "Cannot open file $dbpath: $! $BerkeleyDB::Error\n";

    $all{$_} = $h{$_} for keys %h;

    untie %h;

    my (%idxh, %children, %rhlinks, @check_dirs);

    my @names = keys %all;
    for my $name (@names) {

        my %entry = %{$all{$name}};

        $entry{ownership} =~ s/\s+$//;

        my $file = Lintian::File::Path->new(\%entry);

        my $raw_type = substr($entry{perm}, 0, 1);

        $file->size(0)
          unless $raw_type eq '-';

        # This may appear to be obscene, but the call overhead of
        # perm2oct is measurable on (e.g.) chromium-browser.  With
        # the cache we go from ~1.5s to ~0.1s.
        #   Of the 115363 paths here, only 306 had an "uncached"
        # permission string (chromium-browser/32.0.1700.123-2).
        my $operm = $PERM_CACHE{$file->perm};
        $operm //= perm2oct($file->perm);

        $file->path_info(
            $operm | (
                $FILE_CODE2LPATH_TYPE{$raw_type}
                  // Lintian::File::Path::TYPE_OTHER
            ));

        my ($owner, $group) = split('/', $entry{ownership}, 2);

        # Memory-optimise for root/root.  Perl has an insane overhead
        # for each field, so this is sadly worth it!
        $file->owner($owner);
        $file->group($group);

        if ($name =~ s/ link to (.*)//) {
            my $target = dequote_name($1);
            $file->path_info($FILE_CODE2LPATH_TYPE{'h'} | $operm);
            $file->link($target);

            push @{$rhlinks{$target}}, dequote_name($name);
        } elsif ($raw_type eq 'l') {
            my $target;
            ($name, $target) = split ' -> ', $name, 2;
            $file->link(dequote_name($target, 0));
        } elsif ($raw_type eq 'd') {
            # Ensure directory names always end with  / or we will add them
            # multiple times to our index.
            $name .= '/'
              if substr($name, -1) ne '/';
        }
        # We store the name here, but will replace it later.  The
        # reason for storing it now is that we may need it during the
        # "hard-link fixup"-phase.
        $name = dequote_name($name);
        $file->name($name);

        $idxh{$name} = $file;

        # Record children
        $children{$name} ||= []
          if $raw_type eq 'd';
        my ($parent) = ($name =~ m,^(.+/)?(?:[^/]+/?)$,);
        $parent //= EMPTY;

        $children{$parent} = []
          unless exists $children{$parent};

        # coll/unpacked sorts its output, so the parent dir ought to
        # have been created before this entry.  However, it might not
        # be if an intermediate directory is missing.  NB: This
        # often triggers for the root directory, which is normal.
        push(@check_dirs, $parent)
          unless exists $idxh{$parent};

        # Ensure the "root" is not its own child.  It is not really helpful
        # from an analysis PoV and it creates ref cycles  (and by extension
        # leaks like #695866).
        push(@{ $children{$parent} }, $name)
          unless $parent eq $name;
    }

    while (defined(my $name = pop(@check_dirs))) {
        # check_dirs /can/ contain the same item multiple times.
        if (!exists $idxh{$name}) {
            my $cpy = Lintian::File::Path->new(\%INDEX_FAUX_DIR_TEMPLATE);
            my ($parent) = ($name =~ m,^(.+/)?(?:[^/]+/?)$,);
            $parent //= '';
            $cpy->name($name);
            $idxh{$name} = $cpy;
            $children{$parent} = []
              unless exists $children{$parent};
            push(@{ $children{$parent} }, $name)
              unless $parent eq $name;
            push(@check_dirs, $parent)
              unless exists $idxh{$parent};
        }
    }

    die 'The root dir should be present or have been faked'
      unless $allow_empty || exists $idxh{''};

    for my $file (sort keys %rhlinks) {
        # We remove entries we have fixed up, so check the entry
        # is still there.
        next
          unless exists $rhlinks{$file};
        my $e = $idxh{$file};
        my @check = ($e->name);
        my (%candidates, @sorted, $target);
        while (my $current = pop @check) {
            $candidates{$current} = 1;
            foreach my $rdep (@{$rhlinks{$current}}) {
                # There should not be any cycles, but just in case
                push(@check, $rdep)
                  unless $candidates{$rdep};
            }
            # Remove links we are fixing
            delete $rhlinks{$current};
        }
        # keys %candidates will be a complete list of hardlinks
        # that points (in)directly to $file.  Time to normalize
        # the links.
        #
        # Sort in reverse order (allows pop instead of unshift)
        my @links = reverse sort keys %candidates;
        # Our preferred target
        $target = pop @links;

        foreach my $link (@links) {
            next
              unless exists $idxh{$target};
            my $le = $idxh{$link};
            # We may be "demoting" a "real file" to a "hardlink"
            $le->path_info(($le->path_info & ~Lintian::File::Path::TYPE_FILE)
                | Lintian::File::Path::TYPE_HARDLINK);
            $le->link($target);
        }
        if (defined($target) and $target ne $e->name) {
            $idxh{$target}->path_info((
                    $idxh{$target}->path_info
                      & ~Lintian::File::Path::TYPE_HARDLINK
                )| Lintian::File::Path::TYPE_FILE
            );
            # hardlinks does not have size, so copy that from the original
            # entry.
            $idxh{$target}->size($e->size);
            $e->size(0);
            $idxh{$target}->link(EMPTY);
        }
    }

    # Add them in reverse order - entries in a dir are made
    # objects before the dir itself.
    my @sorted = reverse sort keys %idxh;
    foreach my $file (@sorted) {
        my $entry = $idxh{$file};
        if ($entry->path_info & Lintian::File::Path::TYPE_DIR) {
            my (%child_table, @sorted_children);
            for my $cname (sort(@{ $children{$file} })) {
                my $child = $idxh{$cname};
                my $basename = $child->basename;
                if (substr($basename, -1, 1) eq '/') {
                    $basename = substr($basename, 0, -1);
                }
                $child_table{$basename} = $child;
                push(@sorted_children, $child);
            }
            $entry->sorted_children(\@sorted_children);
            $entry->child_table(\%child_table);
            $entry->fs_info($self->fs_info);
        }
        # Insert name here to share the same storage with the hash key
        $entry->name($file);

        if ($entry->path_info & Lintian::File::Path::TYPE_DIR) {
            for my $child ($entry->children) {
                $child->_set_parent_dir($entry);
            }
        }
    }

    $self->index(\%idxh);

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

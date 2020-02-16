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
use Lintian::Util qw(internal_error open_gz perm2oct dequote_name);

use constant EMPTY => q{};

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
    '_path_info' => $FILE_CODE2LPATH_TYPE{'d'} | 0755,
    # Pick a "random" (but fixed) date
    # - hint, it's a good read.  :)
    'date_time'  => '1998-01-25 22:55:34',
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

=item load_info

Returns the hash used during setup.

=item saved_index

Returns a reference to a hash with elements indexed by path names.

=item saved_sorted_list

Returns a reference to a sorted array with path names.

=item C<basedir>

Returns the base directory for file references.

=cut

has load_info => (is => 'rw', default => sub { {} });
has saved_index => (is => 'rw', default => sub { {} });
has saved_sorted_list => (is => 'rw', default => sub { [] });
has basedir => (is => 'rw', default => EMPTY);

=item index (FILE)

Like L</index> except orig_index is based on the "orig tarballs" of
the source packages.

For native packages L</index> and L</orig_index> are generally
identical.

NB: If sorted_index includes a debian packaging, it is was
contained in upstream part of the source package (or the package is
native).

Needs-Info requirements for using I<orig_index>: src-orig-index

=cut

sub index {
    my ($self, $file) = @_;

    # get root dir by default
    $file //= EMPTY;

    unless (scalar keys %{$self->saved_index}) {

        my $index = $self->_fetch_index_data($self->load_info);
        $self->saved_index($index);

        my @sorted = sort keys %{$index};
        # remove "top" dir in sorted_index; it is hardly ever used
        # it is always present because we create it if needed
        # it is always the first entry; the list is sorted
        shift @sorted;
        @sorted = map { $index->{$_} } @sorted;

        $self->saved_sorted_list(\@sorted);
    }

    return $self->saved_index->{$file}
      if exists $self->saved_index->{$file};

    return;
}

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

    # orig_index does all our work for us, so call it if
    # sorted_orig_index has not been created yet.

    $self->index
      unless scalar @{ $self->saved_sorted_list };

    return @{ $self->saved_sorted_list };
}

# Backing method for index and others; this is not a part of the API.
# sub _fetch_index_data Needs-Info none
sub _fetch_index_data {
    my ($self, $load_info) = @_;

    my $index = $load_info->{'index_file'} // EMPTY;
    my $allow_empty = $load_info->{'allow_empty'} // 0;
    my $has_anchored_root_dir = $load_info->{'has_anchored_root_dir'} // 0;
    my $fs_root_sub = $load_info->{'fs_root_sub'};
    my $file_info_sub = $load_info->{'file_info_sub'};

    my $fs_info = Lintian::Path::FSInfo->new(
        '_collect_path_sub' => $fs_root_sub,
        '_collect_file_info_sub' => $file_info_sub,
        'has_anchored_root_dir' => $has_anchored_root_dir,
    );

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

        my $perm = $entry{perm};
        my $ownership = $entry{ownership};
        my $size = $entry{size};
        my $date = $entry{date};
        my $time = $entry{time};
        my $uid = $entry{uid};
        my $gid = $entry{gid};

        my (%file, $operm, $raw_type);

        $ownership =~ s/\s+$//;
        $time //= '00:00';

        $file{'date_time'} = "$date $time";
        $raw_type = substr($perm, 0, 1);

        # Only set size if it is non-zero and even then, only for
        # regular files.  When we set it, insist on it being an int.
        # This makes perl store it slightly more efficient.
        $file{'size'} = int($size)
          if $size and $raw_type eq '-';

        # This may appear to be obscene, but the call overhead of
        # perm2oct is measurable on (e.g.) chromium-browser.  With
        # the cache we go from ~1.5s to ~0.1s.
        #   Of the 115363 paths here, only 306 had an "uncached"
        # permission string (chromium-browser/32.0.1700.123-2).
        $operm = $PERM_CACHE{$perm};
        $operm = perm2oct($perm)
          unless defined $operm;

        $file{'_path_info'} = $operm| ($FILE_CODE2LPATH_TYPE{$raw_type}
              // Lintian::File::Path::TYPE_OTHER);

        $file{'uid'} = $uid
          if $uid;
        $file{'gid'} = $gid
          if $gid;

        my ($owner, $group) = split('/', $ownership, 2);

        # Memory-optimise for root/root.  Perl has an insane overhead
        # for each field, so this is sadly worth it!
        $file{'owner'} = $owner
          if $owner ne 'root' and $owner ne '0';
        $file{'group'} = $group
          if $group ne 'root' and $group ne '0';

        if ($name =~ s/ link to (.*)//) {
            my $target = dequote_name($1);
            $file{'_path_info'} = $FILE_CODE2LPATH_TYPE{'h'} | $operm;
            $file{link} = $target;

            push @{$rhlinks{$target}}, dequote_name($name);
        } elsif ($raw_type eq 'l') {
            ($name, $file{link}) = split ' -> ', $name, 2;
            $file{link} = dequote_name($file{link}, 0);
        } elsif ($raw_type eq 'd') {
            # Ensure directory names always end with  / or we will add them
            # multiple times to our index.
            $name .= '/'
              if substr($name, -1) ne '/';
        }
        # We store the name here, but will replace it later.  The
        # reason for storing it now is that we may need it during the
        # "hard-link fixup"-phase.
        $file{'name'} = $name = dequote_name($name);

        $idxh{$name} = \%file;

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
            my %cpy = %INDEX_FAUX_DIR_TEMPLATE;
            my ($parent) = ($name =~ m,^(.+/)?(?:[^/]+/?)$,);
            $parent //= '';
            $cpy{'name'} = $name;
            $idxh{$name} = \%cpy;
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
        my @check = ($e->{name});
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
            $le->{'_path_info'}
              = ($le->{'_path_info'} & ~Lintian::File::Path::TYPE_FILE)
              | Lintian::File::Path::TYPE_HARDLINK;
            $le->{link} = $target;
        }
        if (defined($target) and $target ne $e->{name}) {
            $idxh{$target}{'_path_info'}
              = ($idxh{$target}{'_path_info'}
                  & ~Lintian::File::Path::TYPE_HARDLINK)
              | Lintian::File::Path::TYPE_FILE;
            # hardlinks does not have size, so copy that from the original
            # entry.
            $idxh{$target}{'size'} = $e->{'size'}
              if exists($e->{'size'});
            delete($e->{'size'});
            delete $idxh{$target}{link};
        }
    }

    # Add them in reverse order - entries in a dir are made
    # objects before the dir itself.
    my @sorted = reverse sort keys %idxh;
    foreach my $file (@sorted) {
        my $entry = $idxh{$file};
        if ($entry->{'_path_info'} & Lintian::File::Path::TYPE_DIR) {
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
            $entry->{'_sorted_children'} = \@sorted_children;
            $entry->{'children'} = \%child_table;
            $entry->{'_fs_info'} = $fs_info;
        }
        # Insert name here to share the same storage with the hash key
        $entry->{'name'} = $file;
        $idxh{$file} = Lintian::File::Path->new($entry);
    }

    return \%idxh;
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

# -*- perl -*- Lintian::Index
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

package Lintian::Index;

use v5.20;
use warnings;
use utf8;
use autodie;

use Carp;
use Cwd;
use IPC::Run3;
use List::MoreUtils qw(any);
use Path::Tiny;

use Lintian::Index::Item;
use Lintian::IO::Select qw(unpack_and_index_piped_tar);
use Lintian::IPC::Run3 qw(safe_qx);

use Lintian::Util qw(perm2oct);

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant SLASH => q{/};

use Moo;
use namespace::clean;

with
  'Lintian::Index::Ar',
  'Lintian::Index::Control::Scripts',
  'Lintian::Index::FileInfo',
  'Lintian::Index::Java',
  'Lintian::Index::Md5sums',
  'Lintian::Index::Objdump',
  'Lintian::Index::Scripts',
  'Lintian::Index::Strings';

my %FILE_CODE2LPATH_TYPE = (
    '-' => Lintian::Index::Item::TYPE_FILE| Lintian::Index::Item::OPEN_IS_OK,
    'h' => Lintian::Index::Item::TYPE_HARDLINK
      | Lintian::Index::Item::OPEN_IS_OK,
    'd' => Lintian::Index::Item::TYPE_DIR| Lintian::Index::Item::FS_PATH_IS_OK,
    'l' => Lintian::Index::Item::TYPE_SYMLINK,
    'b' => Lintian::Index::Item::TYPE_BLOCK_DEV,
    'c' => Lintian::Index::Item::TYPE_CHAR_DEV,
    'p' => Lintian::Index::Item::TYPE_PIPE,
);

=head1 NAME

Lintian::Index - access to collected data about the upstream (orig) sources

=head1 SYNOPSIS

    use Lintian::Index;

=head1 DESCRIPTION

Lintian::Processable::Orig::Index provides an interface to collected data about the upstream (orig) sources.

=head1 INSTANCE METHODS

=over 4

=item catalog

Returns a reference to a hash with elements catalogued by path names.

=item saved_sorted_list

Returns a reference to a sorted array with path names.

=item C<basedir>

Returns the base directory for file references.

=item C<anchored>

=cut

has catalog => (
    is => 'rw',
    default => sub {
        my ($self) = @_;

        # create an empty root
        my $root = Lintian::Index::Item->new;

        # associate with this index
        $root->index($self);

        my %catalog;
        $catalog{''} = $root;

        return \%catalog;
    });
has saved_sorted_list => (is => 'rw', default => sub { [] });

has basedir => (
    is => 'rw',
    trigger => sub {
        my ($self, $folder) = @_;

        return
          unless length $folder;

        # create directory
        path($folder)->mkpath({ chmod => 0777 })
          unless -e $folder;
    },
    default => EMPTY
);

has anchored => (is => 'rw', default => 0);

=item sorted_list

=cut

sub sorted_list {
    my ($self) = @_;

    unless (scalar @{ $self->saved_sorted_list }) {

        my @sorted = sort { $a->name cmp $b->name } values %{$self->catalog};

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

=cut

sub lookup {
    my ($self, $name) = @_;

    # get root dir by default
    $name //= EMPTY;

    croak 'Name is not a string'
      unless ref $name eq EMPTY;

    my $found = $self->catalog->{$name};

    return $found
      if defined $found;

    return;
}

=item resolve_path

=cut

sub resolve_path {
    my ($self, $name) = @_;

    return $self->lookup->resolve_path($name);
}

=item create_from_basedir

=cut

sub create_from_basedir {
    my ($self) = @_;

    my $savedir = getcwd;
    chdir($self->basedir);

    # get times in UTC
    my @index_command
      = ('env', 'TZ=UTC', 'find', '-printf', '%M %s %A+\0%p\0%l\0');
    my $index_output;
    my $index_errors;

    run3(\@index_command, \undef, \$index_output, \$index_errors);

    chdir($savedir);

    my $permissionspattern = qr,\S{10},;
    my $sizepattern = qr,\d+,;
    my $datepattern = qr,\d{4}-\d{2}-\d{2},;
    my $timepattern = qr,\d{2}:\d{2}:\d{2}\.\d+,;
    my $pathpattern = qr,[^\0]*,;

    my %all;

    $index_output =~ s/\0$//;

    my @lines = split(/\0/, $index_output, -1);
    die 'Did not get a multiple of three lines from find.'
      unless @lines % 3 == 0;

    while (defined(my $first = shift @lines)) {

        my $entry = Lintian::Index::Item->new;
        $entry->index($self);

        $first
          =~ /^($permissionspattern)\ ($sizepattern)\ ($datepattern)\+($timepattern)$/s;

        $entry->perm($1);
        $entry->size($2);
        $entry->date($3);
        $entry->time($4);

        my $name = shift @lines;

        my $linktarget = shift @lines;

        # for non-links, string is empty
        $entry->link($linktarget)
          if length $linktarget;

        # find prints single dot for base; removed in next step
        $name =~ s{^\.$}{\./}s;

        # strip relative prefix
        $name =~ s{^\./+}{}s;

        # make sure directories end with a slash, except root
        $name .= SLASH
          if length $name
          && $entry->perm =~ /^d/
          && substr($name, -1) ne SLASH;
        $entry->name($name);

        $all{$entry->name} = $entry;
    }

    $self->catalog(\%all);

    $self->load;

    return ($index_errors);
}

=item create_from_piped_tar

=cut

sub create_from_piped_tar {
    my ($self, $command) = @_;

    my $extract_dir = $self->basedir;

    my ($named, $numeric, $extract_errors, $index_errors)
      = unpack_and_index_piped_tar($command, $extract_dir);

    # fix permissions
    safe_qx('chmod', '-R', 'u+rwX,go-w', $extract_dir);

    my @named_owner = split(/\n/, $named);
    my @numeric_owner = split(/\n/, $numeric);

    my %catalog;

    for my $line (@named_owner) {

        my $entry = Lintian::Index::Item->new;
        $entry->init_from_tar_output($line);
        $entry->index($self);

        $catalog{$entry->name} = $entry;
    }

    # get numerical owners from second list
    for my $line (@numeric_owner) {

        # entry not used outside this loop
        my $entry = Lintian::Index::Item->new;
        $entry->init_from_tar_output($line);

        die 'Numerical index lists extra files for file name '. $entry->name
          unless exists $catalog{$entry->name};

        # keep numerical uid and gid
        $catalog{$entry->name}->uid($entry->owner);
        $catalog{$entry->name}->gid($entry->group);
    }

    $self->catalog(\%catalog);

    $self->load;

    return ($extract_errors, $index_errors);
}

=item load

=cut

sub load {
    my ($self) = @_;

    my %all = %{$self->catalog};

    # set internal permissions flags
    for my $entry (values %all) {

        my $raw_type = substr($entry->perm, 0, 1);

        my $operm = perm2oct($entry->perm);
        $entry->path_info(
            $operm | (
                $FILE_CODE2LPATH_TYPE{$raw_type}
                  // Lintian::Index::Item::TYPE_OTHER
            ));
    }

    # find all entries that are not regular files
    my @nosize
      = grep { !$_->path_info & Lintian::Index::Item::TYPE_FILE } values %all;

    # reset size for anything but regular files
    $_->size(0) for @nosize;

    if ($self->anchored) {

        my %relative;
        for my $name (keys %all) {
            my $entry = $all{$name};

            # remove leading slash from absolute names
            my $name = $entry->name;
            $name =~ s{^/+}{}s;
            $entry->name($name);

            # remove leading slash from absolute hardlink targets
            if ($entry->is_hardlink) {
                my $target = $entry->link;
                $target =~ s{^/+}{}s;
                $entry->link($target);
            }

            $relative{$name} = $entry;
        }

        %all = %relative;
    }

    # disallow absolute names
    die 'Index contains absolute path names'
      if any { $_->name =~ m{^/}s } values %all;

    # disallow absolute hardlink targets
    die 'Index contains absolute hardlink targets'
      if any { $_->link =~ m{^/}s } grep { $_->is_hardlink } values %all;

    # add entries for missing directories
    for my $entry (values %all) {

        my $current = $entry;
        my $parentname;

        # travel up the directory tree
        do {
            $parentname = $current->dirname;

            # insert new entry for missing intermediate directories
            unless (exists $all{$parentname}) {

                my $added = Lintian::Index::Item->new;
                $added->index($self);

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

    # insert root for empty tarfies like suckless-tools_45.orig.tar.xz
    unless (exists $all{''}) {

        my $root = Lintian::Index::Item->new;
        $root->index($self);

        $root->name(EMPTY);
        $root->path_info($FILE_CODE2LPATH_TYPE{'d'} | 0755);

        # random but fixed date; hint, it's a good read. :)
        $root->date('1998-01-25');
        $root->time('22:55:34');
        $root->faux(1);

        $all{''} = $root;
    }

    my @directories
      = grep { $_->path_info & Lintian::Index::Item::TYPE_DIR } values %all;

    # make space for children
    my %children;
    $children{$_->name} = [] for @directories;

    # record children
    for my $entry (values %all) {

        my $parentname = $entry->dirname;

        # Ensure the "root" is not its own child.  It is not really helpful
        # from an analysis PoV and it creates ref cycles  (and by extension
        # leaks like #695866).
        push(@{ $children{$parentname} }, $entry)
          unless $parentname eq $entry->name;
    }

    foreach my $entry (@directories) {
        my %childnames
          = map {$_->basename => $_->name }@{ $children{$entry->name} };
        $entry->childnames(\%childnames);
    }

    # ensure root is not its own child; may create leaks like #695866
    die 'Root directory is its own parent'
      if defined $all{''} && defined $all{''}->parent_dir;

    # find all hard links
    my @hardlinks
      = grep { $_->path_info & Lintian::Index::Item::TYPE_HARDLINK }
      values %all;

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
            ($preferred->path_info& ~Lintian::Index::Item::TYPE_HARDLINK)
            | Lintian::Index::Item::TYPE_FILE);

        foreach my $pointer (@links) {

            # turn into a hard link
            $pointer->path_info(
                ($pointer->path_info & ~Lintian::Index::Item::TYPE_FILE)
                | Lintian::Index::Item::TYPE_HARDLINK);

            # set link to preferred path
            $pointer->link($preferred->name);

            # no size for hardlinks
            $pointer->size(0);
        }
    }

    # make sure recorded names match hash keys
    $all{$_}->name($_) for keys %all;

    $self->catalog(\%all);

    $self->add_md5sums;
    $self->add_fileinfo;
    $self->add_scripts;
    $self->add_control;

    $self->add_ar;
    $self->add_java;
    $self->add_objdump;
    $self->add_strings;

    return;
}

=item merge_in

=cut

sub merge_in {
    my ($self, $other) = @_;

    die 'Need same base directory ('
      . $self->basedir . ' vs '
      . $other->basedir . ')'
      unless $self->basedir eq $other->basedir;

    die 'Need same anchoring status'
      unless $self->anchored == $other->anchored;

    # associate all new items with this index
    $_->index($self) for values %{$other->catalog};

    # do not transfer root
    $self->catalog->{$_->name} = $_
      for grep { $_->name ne EMPTY } values %{$other->catalog};

    # add children that came from other root to current
    my @other_childnames = keys %{$other->catalog->{''}->childnames};
    for my $name (@other_childnames) {

        $self->catalog->{''}->childnames->{$name} = $self->catalog->{$name};
    }

    # remove items from other index
    $other->catalog({});

    # unset other base directory
    $other->basedir(EMPTY);

    return;
}

=item capture_common_prefix

=cut

sub capture_common_prefix {
    my ($self) = @_;

    my $new_basedir = path($self->basedir)->parent;

    # do nothing in root
    return
      if $new_basedir eq SLASH;

    my $segment = path($self->basedir)->basename;
    die 'Common path segment has no length'
      unless length $segment;

    my $prefix;
    if ($self->anchored) {
        $prefix = SLASH . $segment;
    } else {
        $prefix = $segment . SLASH;
    }

    my $new_root = Lintian::Index::Item->new;

    # associate new item with this index
    $new_root->index($self);

    $new_root->name('');
    $new_root->childnames({ $segment => $prefix });

    # random but fixed date; hint, it's a good read. :)
    $new_root->date('1998-01-25');
    $new_root->time('22:55:34');
    $new_root->path_info($FILE_CODE2LPATH_TYPE{'d'} | 0755);
    $new_root->faux(1);

    my %new_catalog;
    for my $item (values %{$self->catalog}) {

        # drop common prefix from name
        my $new_name = $prefix . $item->name;
        $item->name($new_name);

        if (length $item->link) {

            # add common prefix from link target
            my $new_link = $prefix . $item->link;
            $item->link($new_link);
        }

        # adjust references to children
        for my $basename (keys %{$item->childnames}) {
            $item->childnames->{$basename}
              = $prefix . $item->childnames->{$basename};
        }

        $new_catalog{$new_name} = $item;
    }

    $new_catalog{''} = $new_root;
    $new_catalog{$prefix}->parent_dir($new_root);

    $self->catalog(\%new_catalog);

    # remove segment from base directory
    $self->basedir($new_basedir);

    return;
}

=item drop_common_prefix

=cut

sub drop_common_prefix {
    my ($self) = @_;

    my @childnames = keys %{$self->catalog->{''}->childnames};

    die 'Not exactly one top-level child'
      unless @childnames == 1;

    my $segment = $childnames[0];
    die 'Common path segment has no length'
      unless length $segment;

    my $new_root = $self->lookup($segment . SLASH);
    die 'New root is not a directory'
      unless $new_root->is_dir;

    my $prefix;
    if ($self->anchored) {
        $prefix = SLASH . $segment;
    } else {
        $prefix = $segment . SLASH;
    }

    my $regex = quotemeta($prefix);

    delete $self->catalog->{''};

    my %new_catalog;
    for my $item (values %{$self->catalog}) {

        # drop common prefix from name
        my $new_name = $item->name;
        $new_name =~ s{^$regex}{};
        $item->name($new_name);

        if (length $item->link) {

            # drop common prefix from link target
            my $new_link = $item->link;
            $new_link =~ s{^$regex}{};
            $item->link($new_link);
        }

        # adjust references to children
        for my $basename (keys %{$item->childnames}) {
            $item->childnames->{$basename} =~ s{^$regex}{};
        }

        # unsure this works, but orig not anchored
        $new_name = EMPTY
          if $new_name eq SLASH && $self->anchored;

        $new_catalog{$new_name} = $item;
    }

    $self->catalog(\%new_catalog);

    # add dropped segment to base directory
    $self->basedir($self->basedir . SLASH . $segment);

    $self->drop_basedir_segment;

    return;
}

=item drop_basedir_segment

=cut

sub drop_basedir_segment {
    my ($self) = @_;

    my $obsolete = path($self->basedir)->basename;
    die 'Base directory has no name'
      unless length $obsolete;

    my $parent_dir = path($self->basedir)->parent->stringify;
    die 'Base directory has no parent'
      if $parent_dir eq SLASH;

    my $grandparent_dir = path($parent_dir)->parent->stringify;
    die 'Will not do anything in file system root'
      if $grandparent_dir eq SLASH;

    # destroyed when object is lost
    my $tempdir_tiny
      = path($grandparent_dir)->tempdir(TEMPLATE => 'customXXXXXXXX');

    my $tempdir = $tempdir_tiny->stringify;

    # addresses Perl unicode bug
    utf8::downgrade $tempdir;

    # avoids conflict in case of repeating path segments
    for my $child (path($self->basedir)->children) {
        my $old_name = $child->stringify;

        # addresses Perl unicode bug
        utf8::downgrade $old_name;

        my @command = ('mv', $old_name, $tempdir);
        system(@command);
    }

    rmdir $self->basedir;
    $self->basedir($parent_dir);

    # addresses Perl unicode bug
    utf8::downgrade $parent_dir;

    for my $child ($tempdir_tiny->children) {
        my $old_name = $child->stringify;

        # addresses Perl unicode bug
        utf8::downgrade $old_name;

        my @command = ('mv', $old_name, $parent_dir);
        system(@command);
    }

    return;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

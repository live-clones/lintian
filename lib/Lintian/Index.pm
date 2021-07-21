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

use Carp;
use Const::Fast;
use Cwd;
use IPC::Run3;
use List::SomeUtils qw(any);
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8 decode_utf8);

use Lintian::Index::Item;
use Lintian::IO::Select qw(unpack_and_index_piped_tar);
use Lintian::IPC::Run3 qw(safe_qx);

use Lintian::Util qw(perm2oct);

use Moo;
use namespace::clean;

with
  'Lintian::Index::Ar',
  'Lintian::Index::FileInfo',
  'Lintian::Index::Java',
  'Lintian::Index::Md5sums',
  'Lintian::Index::Objdump',
  'Lintian::Index::Strings';

const my $EMPTY => q{};
const my $SLASH => q{/};
const my $HYPHEN => q{-};
const my $NEWLINE => qq{\n};

const my $WAIT_STATUS_SHIFT => 8;
const my $NO_LIMIT => -1;
const my $LINES_PER_FILE => 3;
const my $WIDELY_READABLE_FOLDER => oct(755);
const my $WORLD_WRITABLE_FOLDER => oct(777);

my %FILE_CODE2LPATH_TYPE = (
    $HYPHEN => Lintian::Index::Item::TYPE_FILE
      | Lintian::Index::Item::OPEN_IS_OK,
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
        $catalog{$EMPTY} = $root;

        return \%catalog;
    });

has basedir => (
    is => 'rw',
    trigger => sub {
        my ($self, $folder) = @_;

        return
          unless length $folder;

        # create directory
        path($folder)->mkpath({ chmod => $WORLD_WRITABLE_FOLDER })
          unless -e $folder;
    },
    default => $EMPTY
);

has anchored => (is => 'rw', default => 0);

has sorted_list => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my @sorted = sort { $a->name cmp $b->name } values %{$self->catalog};

        # remove automatic root dir; list is sorted
        shift @sorted;

        const my @IMMUTABLE => @sorted;

        return \@IMMUTABLE;
    });

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
    $name //= $EMPTY;

    croak encode_utf8('Name is not a string')
      unless ref $name eq $EMPTY;

    my $found = $self->catalog->{$name};

    return $found
      if defined $found;

    return undef;
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
    chdir($self->basedir)
      or die encode_utf8('Cannot change to directory ' . $self->basedir);

    # get times in UTC
    my @index_command
      = ('env', 'TZ=UTC', 'find', '-printf', '%M %s %A+\0%p\0%l\0');
    my $index_output;
    my $index_errors;

    run3(\@index_command, \undef, \$index_output, \$index_errors);

    chdir($savedir)
      or die encode_utf8("Cannot change to directory $savedir");

    # allow processing of file names with non UTF-8 bytes
    $index_errors = decode_utf8($index_errors)
      if length $index_errors;

    my $permissionspattern = qr/\S{10}/;
    my $sizepattern = qr/\d+/;
    my $datepattern = qr/\d{4}-\d{2}-\d{2}/;
    my $timepattern = qr/\d{2}:\d{2}:\d{2}\.\d+/;
    my $pathpattern = qr/[^\0]*/;

    my %all;

    $index_output =~ s/\0$//;

    my @lines = split(/\0/, $index_output, $NO_LIMIT);
    die encode_utf8(
        "Did not get a multiple of $LINES_PER_FILE lines from find.")
      unless @lines % $LINES_PER_FILE == 0;

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
        $name .= $SLASH
          if length $name
          && $entry->perm =~ /^d/
          && $name !~ m{ /$ }msx;
        $entry->name($name);

        $all{$entry->name} = $entry;
    }

    $self->catalog(\%all);

    my $load_errors = $self->load;

    return $index_errors . $load_errors;
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

    # allow processing of file names with non UTF-8 bytes
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

        die encode_utf8(
            'Numerical index lists extra files for file name '. $entry->name)
          unless exists $catalog{$entry->name};

        # keep numerical uid and gid
        $catalog{$entry->name}->uid($entry->owner);
        $catalog{$entry->name}->gid($entry->group);
    }

    # tar produces spurious root entry when stripping slashes from member names
    delete $catalog{$SLASH}
      unless $self->anchored;

    $self->catalog(\%catalog);

    my $load_errors = $self->load;

    return $extract_errors . $index_errors . $load_errors;
}

=item load

=cut

sub load {
    my ($self) = @_;

    my $errors = $EMPTY;

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
    die encode_utf8('Index contains absolute path names')
      if any { $_->name =~ m{^/}s } values %all;

    # disallow absolute hardlink targets
    die encode_utf8('Index contains absolute hardlink targets')
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
                $added->path_info(
                    $FILE_CODE2LPATH_TYPE{'d'} | $WIDELY_READABLE_FOLDER);

                # random but fixed date; hint, it's a good read. :)
                $added->date('1998-01-25');
                $added->time('22:55:34');
                $added->faux(1);

                $all{$parentname} = $added;
            }

            $current = $all{$parentname};

        } while ($parentname ne $EMPTY);
    }

    # insert root for empty tarfies like suckless-tools_45.orig.tar.xz
    unless (exists $all{$EMPTY}) {

        my $root = Lintian::Index::Item->new;
        $root->index($self);

        $root->name($EMPTY);
        $root->path_info($FILE_CODE2LPATH_TYPE{'d'} | $WIDELY_READABLE_FOLDER);

        # random but fixed date; hint, it's a good read. :)
        $root->date('1998-01-25');
        $root->time('22:55:34');
        $root->faux(1);

        $all{$EMPTY} = $root;
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
    die encode_utf8('Root directory is its own parent')
      if defined $all{$EMPTY} && defined $all{$EMPTY}->parent_dir;

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
        $preferred->link($EMPTY);

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

    $errors .= $self->add_md5sums;
    $errors .= $self->add_fileinfo;

    $errors .= $self->add_ar;
    $errors .= $self->add_java;
    $errors .= $self->add_objdump;
    $errors .= $self->add_strings;

    return $errors;
}

=item merge_in

=cut

sub merge_in {
    my ($self, $other) = @_;

    die encode_utf8('Need same base directory ('
          . $self->basedir . ' vs '
          . $other->basedir . ')')
      unless $self->basedir eq $other->basedir;

    die encode_utf8('Need same anchoring status')
      unless $self->anchored == $other->anchored;

    # associate all new items with this index
    $_->index($self) for values %{$other->catalog};

    for my $item (values %{$other->catalog}) {

        # do not transfer root
        next
          if $item->name eq $EMPTY;

        # duplicates on disk are dropped with basedir segments
        $self->catalog->{$item->name} = $item;

        # when adding folder, delete potential file entry
        my $noslash = $item->name;
        if ($noslash =~ s{/$}{}) {
            delete $self->catalog->{$noslash};
        }
    }

    # add children that came from other root to current
    my @other_childnames = keys %{$other->catalog->{$EMPTY}->childnames};
    for my $name (@other_childnames) {

        $self->catalog->{$EMPTY}->childnames->{$name}
          = $self->catalog->{$name};
    }

    # remove items from other index
    $other->catalog({});

    # unset other base directory
    $other->basedir($EMPTY);

    return;
}

=item capture_common_prefix

=cut

sub capture_common_prefix {
    my ($self) = @_;

    my $new_basedir = path($self->basedir)->parent;

    # do nothing in root
    return
      if $new_basedir eq $SLASH;

    my $segment = path($self->basedir)->basename;
    die encode_utf8('Common path segment has no length')
      unless length $segment;

    my $prefix;
    if ($self->anchored) {
        $prefix = $SLASH . $segment;
    } else {
        $prefix = $segment . $SLASH;
    }

    my $new_root = Lintian::Index::Item->new;

    # associate new item with this index
    $new_root->index($self);

    $new_root->name($EMPTY);
    $new_root->childnames({ $segment => $prefix });

    # random but fixed date; hint, it's a good read. :)
    $new_root->date('1998-01-25');
    $new_root->time('22:55:34');
    $new_root->path_info($FILE_CODE2LPATH_TYPE{'d'} | $WIDELY_READABLE_FOLDER);
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

    $new_catalog{$EMPTY} = $new_root;
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

    my $errors = $EMPTY;

    my @childnames = keys %{$self->catalog->{$EMPTY}->childnames};

    die encode_utf8('Not exactly one top-level child')
      unless @childnames == 1;

    my $segment = $childnames[0];
    die encode_utf8('Common path segment has no length')
      unless length $segment;

    my $new_root = $self->lookup($segment . $SLASH);
    die encode_utf8('New root is not a directory')
      unless $new_root->is_dir;

    my $prefix;
    if ($self->anchored) {
        $prefix = $SLASH . $segment;
    } else {
        $prefix = $segment . $SLASH;
    }

    my $regex = quotemeta($prefix);

    delete $self->catalog->{$EMPTY};

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
        $new_name = $EMPTY
          if $new_name eq $SLASH && $self->anchored;

        $new_catalog{$new_name} = $item;
    }

    $self->catalog(\%new_catalog);

    # add dropped segment to base directory
    $self->basedir($self->basedir . $SLASH . $segment);

    my $other_errors = $self->drop_basedir_segment;

    return $errors . $other_errors;
}

=item drop_basedir_segment

=cut

sub drop_basedir_segment {
    my ($self) = @_;

    my $errors = $EMPTY;

    my $obsolete = path($self->basedir)->basename;
    die encode_utf8('Base directory has no name')
      unless length $obsolete;

    my $parent_dir = path($self->basedir)->parent->stringify;
    die encode_utf8('Base directory has no parent')
      if $parent_dir eq $SLASH;

    my $grandparent_dir = path($parent_dir)->parent->stringify;
    die encode_utf8('Will not do anything in file system root')
      if $grandparent_dir eq $SLASH;

    # destroyed when object is lost
    my $tempdir_tiny
      = path($grandparent_dir)->tempdir(TEMPLATE => 'customXXXXXXXX');

    my $tempdir = $tempdir_tiny->stringify;

    # avoids conflict in case of repeating path segments
    for my $child (path($self->basedir)->children) {
        my $old_name = $child->stringify;

        # Perl unicode bug
        utf8::downgrade $old_name;
        utf8::downgrade $tempdir;

        my @command = ('mv', $old_name, $tempdir);
        my $stderr;
        run3(\@command, \undef, \undef, \$stderr);
        my $status = ($? >> $WAIT_STATUS_SHIFT);

        # already in UTF-8
        die $stderr
          if $status;
    }

    rmdir $self->basedir;
    $self->basedir($parent_dir);

    for my $child ($tempdir_tiny->children) {
        my $old_name = $child->stringify;

        my $target_dir = $parent_dir . $SLASH . $child->basename;

        # Perl unicode bug
        utf8::downgrade $target_dir;

        if (-e $target_dir) {

            # catalog items were dropped when index was merged
            my @command = (qw{rm -rf}, $target_dir);
            my $stderr;
            run3(\@command, \undef, \undef, \$stderr);
            my $status = ($? >> $WAIT_STATUS_SHIFT);

            # already in UTF-8
            die $stderr
              if $status;

            my $display_dir
              = path($parent_dir)->basename . $SLASH . $child->basename;
            $errors .= "removed existing $display_dir" . $NEWLINE;
        }

        # Perl unicode bug
        utf8::downgrade $old_name;
        utf8::downgrade $parent_dir;

        my @command = ('mv', $old_name, $parent_dir);
        my $stderr;
        run3(\@command, \undef, \undef, \$stderr);
        my $status = ($? >> $WAIT_STATUS_SHIFT);

        # already in UTF-8
        die $stderr
          if $status;
    }

    return $errors;
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

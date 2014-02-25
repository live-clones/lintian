# -*- perl -*-
# Lintian::Collect::Package -- interface to data collection for packages

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

# This handles common things for things available in source and binary packages
package Lintian::Collect::Package;

use strict;
use warnings;
use autodie;

use parent 'Lintian::Collect';

use Carp qw(croak);
use Scalar::Util qw(blessed);

use Lintian::Path;
use Lintian::Util qw(fail open_gz perm2oct normalize_pkg_path dequote_name);

my %ROOT_INDEX_TEMPLATE = (
    'name'     => '',
    'type'     => 'd',
    'basename' => '',
    'dirname'  => '',
    'owner'    => 'root',
    'group'    => 'root',
    'size'     => 0,
    # Pick a "random" (but fixed) date
    # - hint, it's a good read.  :)
    'date'     => '1998-01-25',
    'time'     => '22:55:34',
);

=head1 NAME

Lintian::Collect::Package - Lintian base interface to binary and source package data collection

=head1 SYNOPSIS

    use autodie;
    use Lintian::Collect;
    
    my ($name, $type, $dir) = ('foobar', 'source', '/path/to/lab-entry');
    my $info = Lintian::Collect->new ($name, $type, $dir);
    my $filename = "etc/conf.d/$name.conf";
    my $file = $info->index($filename);
    if ($file && $file->is_regular_file) {
        open(my $fd, '<', $info->unpacked($file));
        # Use $fd ...
        close($fd);
    } elsif ($file) {
        print "$file is available, but not a regular file\n";
    } else {
        print "$file is missing\n";
    }

=head1 DESCRIPTION

Lintian::Collect::Package provides part of an interface to package
data for source and binary packages.  It implements data collection
methods specific to all packages that can be unpacked (or can contain
files)

This module is in its infancy.  Most of Lintian still reads all data from
files in the laboratory whenever that data is needed and generates that
data via collect scripts.  The goal is to eventually access all data about
source packages via this module so that the module can cache data where
appropriate and possibly retire collect scripts in favor of caching that
data in memory.

=head1 INSTANCE METHODS

In addition to the instance methods listed below, all instance methods
documented in the L<Lintian::Collect> module are also available.

=over 4

=item unpacked ([FILE])

Returns the path to the directory in which the package has been
unpacked.  FILE must be either a L<Lintian::Path> object (>= 2.5.13~)
or a string denoting the requested path.  In the latter case, the path
must be relative to the root of the package and should be normalized.

It is not permitted for FILE to be C<undef>.  If the "root" dir is
desired either invoke this method without any arguments at all, pass
it the correct L<Lintian::Path> or the empty string.

If FILE is not in the package, it returns the path to a non-existent
file entry.

The path returned is not guaranteed to be inside the Lintian Lab as
the package may have been unpacked outside the Lab (e.g. as
optimization).

Caveat with symlinks: Package is extracted as is and the path returned
by this method points to the extracted file object.  If this is a
symlink, it may "escape the root" and point to a file outside the lab
(and a path traversal).

The following code may be helpful in checking for path traversal:

 use Lintian::Util qw(is_ancestor_of);

 my $collect = ... ;
 my $file = '../../../etc/passwd';
 my $uroot = $collect->unpacked;
 my $ufile = $collect->unpacked($file);
 # $uroot will exist, but $ufile might not.
 if ( -e $ufile && is_ancestor_of($uroot, $ufile)) {
    # has not escaped $uroot
    do_stuff($ufile);
 } elsif ( -e $ufile) {
    # escaped $uroot
    die "Possibly path traversal ($file)";
 } else {
    # Does not exists
 }

Alternatively one can use normalize_pkg_path in L<Lintian::Util> or
L<link_normalized|Lintian::Path/link_normalized>.

To get a list of entries in the package or the file meta data of the
entries (as L<path objects|Lintian::Path>), see L</sorted_index> and
L</index (FILE)>.

Needs-Info requirements for using I<unpacked>: unpacked

=cut

sub unpacked {
    ## no critic (Subroutines::RequireArgUnpacking)
    #  - _fetch_extracted_dir checks if the FILE argument was explicitly
    #    undef, but it relies on the size of @_ to do this.  With
    #    unpacking we would have to use shift or check it directly here
    #    (and duplicate said check in ::Binary::control and
    #    ::Source::debfiles).
    my $self = shift(@_);
    return $self->_fetch_extracted_dir('unpacked', 'unpacked', @_);
}

=item file_info (FILE)

Returns the output of file(1) -e ascii for FILE (if it exists) or
C<undef>.

B<CAVEAT>: As file(1) is passed "-e ascii", all text files will be
considered "data" rather than "text", "Java code" etc.

NB: The value may have been calibrated by Lintian.  A notorious example
is gzip files, where file(1) can be unreliable at times (see #620289)

Needs-Info requirements for using I<file_info>: file-info

=cut

sub file_info {
    my ($self, $file) = @_;
    if (my $cache = $self->{file_info}) {
        return ${$cache->{$file}}
          if exists $cache->{$file};
        return;
    }
    my %interned;
    my %file_info;
    my $path = $self->lab_data_path('file-info.gz');
    local $_;
    my $idx = open_gz($path);
    while (<$idx>) {
        chomp;

        m/^(.+?)\x00\s+(.*)$/o
          or croak(
            join(q{ },
                'an error in the file pkg is preventing',
                "lintian from checking this package: $_"));
        my ($file, $info) = ($1,$2);
        my $ref = $interned{$info};

        $file =~ s,^\./,,o;

        if (!defined($ref)) {
            # Store a ref to the info to avoid creating a new copy
            # each time.  We just have to deref the reference on
            # return.  TODO: Test if this will be obsolete by
            # COW variables in Perl 5.20.
            $interned{$info} = $ref = \$info;
        }

        $file_info{$file} = $ref;
    }
    close($idx);
    $self->{file_info} = \%file_info;

    return ${$self->{file_info}{$file}}
      if exists $self->{file_info}->{$file};
    return;
}

=item md5sums

Returns a hashref mapping a FILE to its md5sum.  The md5sum is
computed by Lintian during extraction and is not guaranteed to match
the md5sum in the "md5sums" control file.

Needs-Info requirements for using I<md5sums>: md5sums

=cut

sub md5sums {
    my ($self) = @_;
    return $self->{md5sums} if exists $self->{md5sums};
    my $md5f = $self->lab_data_path('md5sums');
    my $result = {};

    # read in md5sums info file
    open(my $fd, '<', $md5f);
    while (my $line = <$fd>) {
        chop($line);
        next if $line =~ m/^\s*$/o;
        $line =~ m/^(?'escaped'\\)?(?'md5sum'\S+)\s*(?'file'\S.*)$/o
          or fail "syntax error in $md5f info file: $line";
        my $zzsum = $+{'md5sum'};
        my $zzescaped = defined($+{'escaped'});
        my $zzfile = $+{'file'};
        if($zzescaped) {
            $zzfile = dequote_name($zzfile);
        }
        $zzfile =~ s,^(?:\./)?,,o;
        $result->{$zzfile} = $zzsum;
    }
    close($fd);
    $self->{md5sums} = $result;
    return $result;
}

=item index (FILE)

Returns a L<path object|Lintian::Path> to FILE in the package.  FILE
must be relative to the root of the unpacked package and must be
without leading slash (or "./").  If FILE is not in the package, it
returns C<undef>.  If FILE is supposed to be a directory, it must be
given with a trailing slash.  Example:

  my $file = $info->index ("usr/bin/lintian");
  my $dir = $info->index ("usr/bin/");

To get a list of entries in the package, see L</sorted_index>.  To
actually access the underlying file (e.g. the contents), use
L</unpacked ([FILE])>.

Note that the "root directory" (denoted by the empty string) will
always be present, even if the underlying tarball omits it.

Needs-Info requirements for using I<index>: index

=cut

sub index {
    my ($self, $file) = @_;
    return $self->_fetch_index_data('index', 'index', 'index-owner-id', $file);
}

=item sorted_index

Returns a sorted array of file names listed in the package.  The names
will not have a leading slash (or "./") and can be passed to
L</unpacked ([FILE])> or L</index (FILE)> as is.

The array will not contain the entry for the "root" of the package.

NB: For source packages, please see the
L<"index"-caveat|Lintian::Collect::Source/index (FILE)>.

Needs-Info requirements for using I<sorted_index>: L<Same as index|/index (FILE)>

=cut

sub sorted_index {
    my ($self) = @_;
    # index does all our work for us, so call it if sorted_index has
    # not been created yet.
    $self->index('') unless exists $self->{sorted_index};
    return @{ $self->{sorted_index} };
}

# Backing method for unpacked, debfiles and others; this is not a part of the
# API.
# sub _fetch_extracted_dir Needs-Info none
sub _fetch_extracted_dir {
    my ($self, $field, $dirname, $file) = @_;
    my $dir = $self->{$field};
    my $filename = '';
    my $normalized = 0;
    if (not defined $dir) {
        $dir = $self->lab_data_path($dirname);
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
            if (!blessed($file) || !$file->isa('Lintian::Path')) {
                croak('Input file must be a string or a Lintian::Path object');
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

# Backing method for index and others; this is not a part of the API.
# sub _fetch_index_data Needs-Info none
sub _fetch_index_data {
    my ($self, $field, $index, $indexown, $file) = @_;
    if (my $cache = $self->{$field}) {
        return $cache->{$file}
          if exists $cache->{$file};
        return;
    }
    my $base_dir = $self->base_dir;
    my (%idxh, %children);
    my $num_idx;
    my %rhlinks;
    my @sorted;
    local $_;
    my $idx = open_gz("$base_dir/${index}.gz");

    if ($indexown) {
        $num_idx = open_gz("$base_dir/${indexown}.gz");
    }
    while (<$idx>) {
        chomp;

        my (%file, $perm, $owner, $name);
        ($perm,$owner,$file{size},$file{date},$file{time},$name)
          =split(' ', $_, 6);
        $file{operm} = perm2oct($perm);
        $file{type} = substr $perm, 0, 1;

        if ($num_idx) {
            # If we have a "numeric owner" index file, read that as well
            my $numeric = <$num_idx>;
            chomp $numeric;
            croak 'cannot read index file $indexown' unless defined $numeric;
            my ($owner_id, $name_chk) = (split(' ', $numeric, 6))[1, 5];
            croak "mismatching contents of index files: $name $name_chk"
              if $name ne $name_chk;
            ($file{uid}, $file{gid}) = split '/', $owner_id, 2;
        }

        ($file{owner}, $file{group}) = split '/', $owner, 2;

        $file{owner} = 'root' if $file{owner} eq '0';
        $file{group} = 'root' if $file{group} eq '0';

        if ($name =~ s/ link to (.*)//) {
            my $target = dequote_name($1);
            $file{type} = 'h';
            $file{link} = $target;

            push @{$rhlinks{$target}}, dequote_name($name);
        } elsif ($file{type} eq 'l') {
            ($name, $file{link}) = split ' -> ', $name, 2;
            $file{link} = dequote_name($file{link}, 0);
        }
        # We store the name here, but will replace it later.  The
        # reason for storing it now is that we may need it during the
        # "hard-link fixup"-phase.
        $file{'name'} = $name = dequote_name($name);

        $idxh{$name} = \%file;

        # Record children
        $children{$name} ||= [] if $file{type} eq 'd';
        my ($parent, $base) = ($name =~ m,^(.+/)?([^/]+/?)$,);
        $parent = '' unless defined $parent;
        $base = '' unless defined $base;
        $file{basename} = $base;
        # Insert the dirname field later for all (non-root) entries as
        # it allows us to better reuse memory.
        $file{dirname} = '' if $base eq '';

        $children{$parent} = [] unless exists $children{$parent};
        # Ensure the "root" is not its own child.  It is not really helpful
        # from an analysis PoV and it creates ref cycles  (and by extension
        # leaks like #695866).
        push @{ $children{$parent} }, $name unless $parent eq $name;
    }
    if (!exists($idxh{''})) {
        # The index did not include a "root" dir, so fake one.
        # Note we have to do a copy here, since we will eventually
        # add a "children" field.
        my %cpy = %ROOT_INDEX_TEMPLATE;
        if ($num_idx) {
            $cpy{'uid'} = 0;
            $cpy{'gid'} = 0;
        }
        $idxh{''} = \%cpy;
    }
    if (%rhlinks) {
        foreach my $file (sort keys %rhlinks) {
            # We remove entries we have fixed up, so check the entry
            # is still there.
            next unless exists $rhlinks{$file};
            my $e = $idxh{$file};
            my %candidates = ();
            my @check = ($e->{name});
            my @sorted;
            my $target;
            while (my $current = pop @check) {
                $candidates{$current} = 1;
                foreach my $rdep (@{$rhlinks{$current}}) {
                    # There should not be any cicles, but just in case
                    push @check, $rdep unless $candidates{$rdep};
                }
                # Remove links we are fixing
                delete $rhlinks{$current};
            }
            # keys %candidates will be a complete list of hardlinks
            # that points (in)directly to $file.  Time to normalize
            # the links.
            #
            # Sort in reverse order (allows pop instead of unshift)
            @sorted = reverse sort keys %candidates;
            # Our prefered target
            $target = pop @sorted;

            foreach my $link (@sorted) {
                next unless exists $idxh{$target};
                my $le = $idxh{$link};
                # We may be "demoting" a "real file" to a "hardlink"
                $le->{type} = 'h';
                $le->{link} = $target;
            }
            if ($target ne $e->{name}) {
                $idxh{$target}->{type} = '-';
                # hardlinks does not have size, so copy that from the original
                # entry.
                $idxh{$target}->{size} = $e->{size};
                delete $idxh{$target}->{link};
            }
        }
    }
    @sorted = sort keys %idxh;
    foreach my $file (reverse @sorted) {
        # Add them in reverse order - entries in a dir are made
        # objects before the dir itself.
        if ($idxh{$file}->{type} eq 'd') {
            my @children;
            for my $cname (sort(@{ $children{$file} })) {
                my $child = $idxh{$cname};
                # Insert dirname here to share the same storage with
                # the hash key
                $child->{'dirname'} = $file;
                push(@children, $child);
            }
            $idxh{$file}{children} = \@children;
        }
        # Insert name here to share the same storage with the hash key
        $idxh{$file}{'name'} = $file;
        $idxh{$file} = Lintian::Path->new($idxh{$file});
    }
    $self->{$field} = \%idxh;
    # Remove the "top" dir in the sorted_index as it is hardly ever
    # used.
    # - Note this will always be present as we create it if it is
    #   missing.  It will always be the first entry since we sorted
    #   the list.
    shift @sorted;
    @sorted = map { $idxh{$_} } @sorted;
    $self->{"sorted_$field"} = \@sorted;
    close($idx);
    close($num_idx) if $num_idx;
    return $self->{$field}->{$file} if exists $self->{$field}->{$file};
    return;
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

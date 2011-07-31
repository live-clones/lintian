# Lintian::Internal::PackageList -- Handler for Lintian's Packages List for the Lab

# Copyright (C) 2011 Niels Thykier
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

package Lintian::Internal::PackageList;

use strict;
use warnings;

use base qw(Class::Accessor);

use Carp qw(croak);
use Lintian::Internal::PackageListDiff;

=head1 NAME

Lintian::Inernal::PackageList -- Handler for Lintian's Lab Package List files

=head1 SYNOPSIS

 use Lintian::Internal::PackageList;
 
 my $plist = Lintian::Internal::PackageList->new('binary');
 # Read the file
 $plist->read_list('info/binary-packages');
 # fetch the entry for lintian (if any)
 my $entry = $plist->get('lintian');
 if ( $entry && exits $entry->{'version'} ) {
    print "Lintian has version $entry->{'version'}\n";
 }
 # delete lintian
 $plist->delete('lintian');
 # Write to file if changed
 if ($plist->dirty) {
    $plist->write_list('info/binary-packages');
 }

=head1 DESCRIPTION

Instances of this class provides access to the packages list used by
the Lab as caches.

=head1 METHODS

=over 4

=cut

# these banner lines have to be changed with every incompatible change of the
# binary and source list file formats
## NB: If bumping the BINLIST_FORMAT, remember to kill the UDEB fall back
##     see read_bin_list
use constant BINLIST_FORMAT => "Lintian's list of binary packages in the archive--V4";
use constant SRCLIST_FORMAT => "Lintian's list of source packages in the archive--V4";
use constant CHGLIST_FORMAT => "Lintian's list of changes packages in the archive--V1";

# Previously udeb-files had a different format; allow parsing a udeb file as
# a binary file V4, assuming that is still the binary format at the time.
my $UDEBLIST_FORMAT = "Lintian's list of udeb packages in the archive--V3";

# List of fields in the formats and the order they appear in
#  - for internal usage to read and write the files

# source package lists
my @SRC_FILE_FIELDS = (
        'source',
        'version',
        'maintainer',
        'uploaders',
        'architecture',
        'area',
        'standards-version',
        'binary',
        'files',
        'file',
        'timestamp',
    );
# binary/udeb package lists
my @BIN_FILE_FIELDS = (
        'package',
        'version',
        'source',
        'source-version',
        'file',
        'timestamp',
        'area',
    );
# changes packages lists
my @CHG_FILE_FIELDS = (
        'source',
        'version',
        'file',
        'timestamp',
    );

=item Lintian::Internal::PackageList->new($pkg_type)

Creates a new packages list for a certain type of packages.  This type
defines the format of the files.

The known types are:
 * binary
 * changes
 * source
 * udeb

FIXME: changes do not have a format at the moment.

=cut

sub new {
    my ($class, $pkg_type) = @_;
    my $self = {
        'type'  => $pkg_type,
        'dirty' => 0,
        'state' => {},
    };
    bless $self, $class;
    return $self;
}

=item $plist->dirty()

Returns a truth value if the packages list has changed since it was
last written.

=item $plist->type()

Returns the type of this list.  (one of binary, udeb, source or changes)

=cut


Lintian::Internal::PackageList->mk_ro_accessors(qw(dirty type));

=item $plist->read_list($file)

Replaces the current list with the one in $file.  This will croak on errors.

This will clear the L<dirty|/dirty> flag.

=cut

sub read_list {
    my ($self, $file) = @_;
    my $ehd;
    my $fields;
    return unless -s $file; # empty file -> ignore

    if ($self->{'type'} eq 'source') {
        $ehd = SRCLIST_FORMAT;
        $fields = \@SRC_FILE_FIELDS;
    } elsif ($self->{'type'} eq 'binary' || $self->{'type'} eq 'udeb') {
        $ehd = BINLIST_FORMAT;
        $fields = \@BIN_FILE_FIELDS;
    } elsif ($self->{'type'} eq 'changes') {
        $ehd = CHGLIST_FORMAT;
        $fields = \@CHG_FILE_FIELDS;
    }
    $self->{'state'} = $self->_read_state($file, $ehd, $fields);
    $self->_mark_dirty(0);
    return 1;
}

=item $plist->write_list($file)

Writes the packages list to $file.  This will croak on errors.

This will clear the L<dirty|/dirty> flag.

=cut

sub write_list {
    my ($self, $file) = @_;
    my $header;
    my $state = $self->{'state'};
    my $fields;

    if ($self->{'type'} eq 'source') {
        $header = SRCLIST_FORMAT;
        $fields = \@SRC_FILE_FIELDS;
    } elsif ($self->{'type'} eq 'binary' || $self->{'type'} eq 'udeb') {
        $header = BINLIST_FORMAT;
        $fields = \@BIN_FILE_FIELDS;
    } elsif ($self->{'type'} eq 'changes') {
        $header = CHGLIST_FORMAT;
        $fields = \@CHG_FILE_FIELDS;
    }
    open my $fd, '>', $file or croak "open $file: $!";
    print $fd "$header\n";
    foreach my $entry (sort keys %$state) {
        my %values = %{ $state->{$entry} };
        print $fd join(';', @values{@$fields}) . "\n";
    }
    close $fd or croak "close $file: $!";
    $self->_mark_dirty(0);
    return 1;
}

=item $plist->get($pkg_name);

Fetches the entry for $pkg_name (if any).  Returns C<undef> if the
entry is not known.

=cut

sub get {
    my ($self, $pkg_name) = @_;
    return $self->{'state'}->{$pkg_name};
}

=item $plist->set($pkg_name, $data)

Creates (or overwrites) the entry for $pkg_name.

=cut

sub set {
    my ($self, $pkg_name, $data) = @_;
    my $fields;
    my $pdata;
    my $pkg_type = $self->{'type'};
    if ($pkg_type eq 'source') {
        $fields = \@SRC_FILE_FIELDS;
    } elsif ($pkg_type eq 'binary' || $pkg_type eq 'udeb') {
        $fields = \@BIN_FILE_FIELDS;
    } else {
        $fields = \@CHG_FILE_FIELDS;
    }

    $pdata = map { $_ => $data->{$_} } @$fields;
    $pdata->{$fields->[0]} = $pkg_name;
    $self->{'state'}->{$pkg_name} = $pdata;
    return 1;
}

=item $plist->delete($pkg_name)

Removes the entry for $pkg_name (if any).  This will mark the list as
dirty.

=cut

sub delete {
    my ($self, $pkg_name) = @_;
    delete $self->{'state'}->{$pkg_name};
    $self->_mark_dirty(1);
    return 1;
}

=item $plist->get_all

Returns the all the entry names in the list

=cut

sub get_all {
    my ($self) = @_;
    return keys %{ $self->{'state'} };
}

sub diff {
    my ($self, $olist) = @_;
    croak "Diffing incompatible types" unless $self->{'type'} eq $olist->{'type'};
    my %ocopy = %{ $olist->{'state'} };
    my @changed;
    my @added;
    my @removed;
    my $sstate = $self->{'state'};
    foreach my $sen (keys %$sstate) {
        my $sentry = $sstate->{$sen};
        my $oentry = $ocopy{$sen};
        unless (defined $oentry) {
            push @added, $sen;
            next;
        }
        if ($sentry->{'version'} ne $oentry->{'version'} ||
            $sentry->{'timestamp'} ne $oentry->{'timestamp'}) {
            push @changed, $sen;
        }
        delete $ocopy{$sen}
    }
    @removed = keys %ocopy;
    return Lintian::Internal::PackageListDiff->_new($self->{'type'}, $self, $olist,
                                                   \@added, \@removed, \@changed);
}

### Internal methods ###

# $plist->_mark_dirty($val)
#
# Internal sub to alter the dirty flag. 1 for dirty, 0 for "not dirty"
sub _mark_diry {
    my ($self, $dirty) = @_;
    $self->{'dirty'} = $dirty;
}

# $plist->_do_read_file($file, $header, $fields)
#
# internal sub to actually load the pkg list from $file.
# $header is the expected header (first line excl. newline)
# $fields is a ref to the relevant field list (see @*_FILE_FIELDS)
#  - croaks on error
sub _do_read_file {
    my ($self, $file, $header, $fields) = @_;
    my $count = scalar @$fields;
    my $res = {};
    open my $fd, '<', $file or croak "open $file: $!";
    my $hd = <$fd>;
    chop $hd;
    unless ($hd eq $header) {
      # accept the UDEB 3 header as alternative to the BIN 4 file
      if ($hd ne $UDEBLIST_FORMAT || BINLIST_FORMAT !~ m/archive--V4$/o) {
          close($fd);
          croak "Unknown/unsupported file format ($hd)";
      }
      # ok - was an UDEB 3 file, which is a BIN 4 file with a different header
    }

    while ( my $line = <$fd> ) {
        chop($line);
        next if $line =~ m/^\s*+$/o;
        my (@values) = split m/\;/o, $line, $count;
        my $entry = {};
        unless ($count == scalar @values) {
            close $fd;
            croak "Invalid line in $file at line $. ($_)"
        }
        for( my $i = 0 ; $i < $count ; $i++){
            $entry->{$fields->[$i]} = $values[$i];
        }
        $res->{$values[0]} = $entry;
    }
    close $fd;
    return $res;
}

=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;


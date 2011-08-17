# Copyright (C) 2011 Niels Thykier <niels@thykier.net>
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

## Represents a group of 'Lintian::Processable's
package Lintian::ProcessableGroup;

use strict;
use warnings;

use Util;
use Lintian::Processable;
=head1 NAME

Lintian::ProcessableGroup -- A group of objects that Lintian can process

=head1 SYNOPSIS

 use Lintian::ProcessableGroup;

 my $group = Lintian::ProcessableGroup->new('lintian_2.5.0_i386.changes');
 foreach my $proc ($group->get_processables()){
     printf "%s %s (%s)\n", $proc->pkg_name(),
            $proc->pkg_version(), $proc->pkg_type();
 }
 # etc.

=head1 DESCRIPTION

Instances of this perl class are sets of
L<Lintian::Processable|processables>.  It allows at most one source
and one changes package per set, but multiple binary packages
(provided that the binary is not already in the set).

=head1 METHODS

=over 4

=item Lintian::ProcessableGroup->new([$changes_file])

Creates a group and optionally add all processables from $changes_file.

=cut

sub new {
    my ($class, $changes) = @_;
    my $self = {};
    bless $self, $class;
    $self->_init_group_from_changes($changes)
        if defined $changes;
    return $self;
}

# Internal initialization sub
#  populates $self from a changes file.
sub _init_group_from_changes {
    my ($self, $changes) = @_;
    my ($cinfo, $cdir);
    fail "$changes does not exist" unless -e $changes;
    $cinfo = get_dsc_info ($changes) or
        fail "$changes is not a valid changes file";
    $self->add_new_processable('changes', $changes);
    $cdir = $changes;
    if ( $changes =~ m,^/+[^/]++$,o){
        # it is "/files.changes?"
        #  - In case you were wondering, we were told not to ask :)
        #   See #624149
        $cdir = '/';
    } else {
        # it is "<something>/files.changes"
        $cdir =~ s,(.+)/[^/]+$,$1,;
    }
    foreach my $line (split (/\n/o, $cinfo->{'files'}//'')) {
	my ($file, $pkg_type);
        next unless defined $line;
        chomp($line);
        $line =~ s/^\s++//o;
        next if $line eq '';
        # Ignore files that may lead to path traversal issues.

        # We do not need (in order) md5sum, size, section or priority
        # - just the file name please.
        (undef, undef, undef, undef, $file) = split(/\s+/o, $line);

        # If the field is malformed, $file may be undefined; we also
        # skip it, if it contains a "/" since that is most likely a
        # traversal attempt
        next if !$file || $file =~ m,/,o;

        if (not -f "$cdir/$file") {
            print STDERR "$cdir/$file does not exist, exiting\n";
            exit 2;
        }

        if ($file =~ /\.deb$/o) {
            $pkg_type = 'binary';
        } elsif ($file =~ /\.udeb$/o){
            $pkg_type = 'udeb';
        } elsif ($file =~ /\.dsc$/o){
            $pkg_type = 'source';
        } else {
            # Some file we do not care about (at least not here).
            next;
        }

        $self->add_new_processable($pkg_type, "$cdir/$file");

    }
    return 1;
}

=item $group->add_new_processable($pkg_type, $pkg_path)

Adds a new processable of type $pkg_type from $pkg_path.

This is short hand for:

 $group->add_processable(
    Lintian::Processable->new($pkg_type, $pkg_path));

=cut

sub add_new_processable {
    my ($self, $pkg_type, $pkg_path) = @_;
    return $self->add_processable(
        Lintian::Processable->new($pkg_type, $pkg_path));
}

=item $group->add_processable($proc)

Adds $proc to $group.  At most one source and one changes $proc can be
in a $group.  There can be multiple binary $proc's, as long as they
are all unique.

This will error out if an additional source or changes $proc is added
to the group. Otherwise it will return a truth value if $proc was
added.

=cut

sub add_processable{
    my ($self, $processable) = @_;
    my $pkg_type = $processable->pkg_type();

    if ($pkg_type eq 'changes'){
        fail 'Cannot add another changes file' if (exists $self->{changes});
        $self->{changes} = $processable;
    } elsif ($pkg_type eq 'source'){
        fail 'Cannot add another source package' if (exists $self->{source});
        $self->{source} = $processable;
    } else {
        my $phash;
        my $name = $processable->pkg_name;
        my $version = $processable->pkg_version;
        my $arch = $processable->pkg_arch;
        fail "Unknown type $pkg_type"
            unless ($pkg_type eq 'binary' or $pkg_type eq 'udeb');
        $phash = $self->{$pkg_type};
        if (!defined $phash){
            $phash = {};
            $self->{$pkg_type} = $phash;
        }
        # duplicate ?
        return 0 if (exists $phash->{"${name}_${version}_${arch}"});
        $phash->{"${name}_${version}_${arch}"} = $processable;
    }
    $processable->set_group($self);
    return 1;
}

=item $group->get_processables([$type])

Returns an array of all processables in $group.  The processables are
returned in the following order: changes (if any), source (if any),
all binaries (if any) and all udebs (if any).

This order is based on the original order that Lintian processed
packages in and some parts of the code relies on this order.

In scalar context, this will return a copy to a list ref containing
the processables.

Note if $type is given, then only processables of that type is
returned.

=cut

sub get_processables {
    my ($self, $type) = @_;
    my @result = ();
    if (defined $type){
        # We only want $type
        if ($type eq 'changes' or $type eq 'source'){
            push @result, $self->{$type} if defined $self->{$type};
            return @result;
        }
        return values %{$self->{$type}} if $type eq 'binary' or $type eq 'udeb';
        fail "Unknown type of processable: $type";
    }
    # We return changes, dsc, debs and udebs in that order,
    # because that is the order lintian used to process a changes
    # file (modulo debs<->udebs ordering).
    #
    # Also correctness of other parts rely on this order.
    foreach my $type (qw(changes source)){
        push @result, $self->{$type} if (exists $self->{$type});
    }
    foreach my $type (qw(binary udeb)){
        push @result, values %{$self->{$type}} if (exists $self->{$type});
    }
    return wantarray ? @result : \@result;
}

=item $group->remove_processable($proc)

Removes $proc from $group

=cut

sub remove_processable {
    my ($self, $proc) = @_;
    my $pkg_type = $proc->pkg_type();
    if ($pkg_type eq 'source' or $pkg_type eq 'changes'){
        delete $self->{$pkg_type};
    } elsif (defined $self->{$pkg_type}) {
        my $phash = $self->{$pkg_type};
        my $name = $proc->pkg_name();
        my $version = $proc->pkg_version();
        my $arch = $proc->pkg_arch();
        delete $phash->{"${name}_${version}_${arch}"};
    }
    return 1;
}

=item $group->get_source_processable()

Returns the processable identified as the "source" package (e.g. the dsc).

If $group does not have a source processable, this method returns C<undef>.

=cut

sub get_source_processable {
    my ($self) = @_;
    return $self->{source};
}

=item $group->get_changes_processable()

Returns the processable identified as the "changes" processable (e.g.
the changes file).

If $group does not have a changes processable, this method returns C<undef>.

=cut

sub get_changes_processable {
    my ($self) = @_;
    return $self->{changes};
}

=item $group->get_binary_processables()

Returns all binary (and udeb) processables in $group.

If $group does not have any binary processables then an empty list (or a
ref to an empty list) is returned (based on context).

=cut

sub get_binary_processables {
    my ($self) = @_;
    my @result = ();
    foreach my $type (qw(binary udeb)){
        push @result, values %{$self->{$type}} if (exists $self->{$type});
    }
    return wantarray ? @result : \@result;
}


=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.

=head1 SEE ALSO

lintian(1)

L<Lintain::Processable>

=cut

1;

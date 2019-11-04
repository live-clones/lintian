# -*- perl -*- Lintian::Info::Java -- access to collected java-info data
#
# Copyright © 2019 Felix Lechner
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

package Lintian::Info::Java;

use strict;
use warnings;
use autodie;

use BerkeleyDB;

use Moo::Role;
use namespace::clean;

with 'Lintian::Collect';

=head1 NAME

Lintian::Info::Java - access to collected java-info data

=head1 SYNOPSIS

    use autodie;
    use Lintian::Collect;
    
    my ($name, $type, $dir) = ('foobar', 'source', '/path/to/lab-entry');
    my $info = Lintian::Collect::Binary->new;
    $info->name($name);
    my $filename = "etc/conf.d/$name.conf";
    my $file = $info->index_resolved_path($filename);
    if ($file and $file->is_open_ok) {
        my $fd = $info->open;
        # Use $fd ...
        close($fd);
    } elsif ($file) {
        print "$file is available, but is not a file or unsafe to open\n";
    } else {
        print "$file is missing\n";
    }

=head1 DESCRIPTION

Lintian::Info::Package provides part of an interface to package
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

=item java_info

Returns a hashref containing information about JAR files found in
source packages, in the form I<file name> -> I<info>, where I<info> is
a hash containing the following keys:

=over 4

=item manifest

A hash containing the contents of the JAR file manifest. For instance,
to find the classpath of I<$file>, you could use:

 if (exists $info->java_info->{$file}{'manifest'}) {
     my $cp = $info->java_info->{$file}{'manifest'}{'Class-Path'};
     # ...
 }

NB: Not all jar files have a manifest.  For those without, this will
value will not be available.  Use exists (rather than defined) to
check for it.

=item files

A table of the files in the JAR.  Each key is a file name and its value
is its "Major class version" for Java or "-" if it is not a class file.

=item error

If it exists, this is an error that occurred during reading of the zip
file.  If it exists, it is unlikely that the other fields will be
present.

=back

Needs-Info requirements for using I<java_info>: java-info

=cut

has saved_java_info => (is => 'rw', default => sub { {} });

sub java_info {
    my ($self) = @_;

    # do something to prevent second lookup
    unless (keys %{$self->saved_java_info}) {

        my $dbpath = $self->lab_data_path('java-info.db');

        # no jar files
        return $self->saved_java_info
          unless -f $dbpath;

        my %java_info;

        tie my %h, 'MLDBM',-Filename => $dbpath
          or die "Cannot open file $dbpath: $! $BerkeleyDB::Error\n";

        $java_info{$_} = $h{$_} for keys %h;

        untie %h;

        $self->saved_java_info(\%java_info);
    }

    return $self->saved_java_info;
}

1;

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1), L<Lintian::Collect>, L<Lintian::Collect::Binary>,
L<Lintian::Collect::Source>

=cut

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
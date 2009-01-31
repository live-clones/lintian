# -*- perl -*-
# Lintian::Collect::Source -- interface to source package data collection

# Copyright (C) 2008 Russ Allbery
# Copyright (C) 2009 Raphael Geissert
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

package Lintian::Collect::Source;
use strict;

use Lintian::Collect;
use Parse::DebianChangelog;
use Util;

our @ISA = qw(Lintian::Collect);

# Initialize a new source package collect object.  Takes the package name,
# which is currently unused.
sub new {
    my ($class, $pkg) = @_;
    my $self = {};
    bless($self, $class);
    return $self;
}

# Get the changelog file of a source package as a Parse::DebianChangelog
# object.  Returns undef if the changelog file couldn't be found.
sub changelog {
    my ($self) = @_;
    return $self->{changelog} if exists $self->{changelog};
    if (-l 'debfiles/changelog' || ! -f 'debfiles/changelog') {
        $self->{changelog} = undef;
    } else {
        my %opts = (infile => 'debfiles/changelog', quiet => 1);
        $self->{changelog} = Parse::DebianChangelog->init(\%opts);
    }
    return $self->{changelog};
}

# Returns whether the package is a native package.  For everything except
# format 3.0 (quilt) packages, we base this on whether we have a Debian
# *.diff.gz file.  3.0 (quilt) packages are always non-native.  Returns true
# if the package is native and false otherwise.
sub native {
    my ($self) = @_;
    return $self->{native} if exists $self->{native};
    my $format = $self->field('format');
    if ($format =~ /^\s*3\.0\s+\(quilt\)\s*$/) {
        $self->{native} = 0;
    } else {
        my $version = $self->field('version');
        $version =~ s/^\d+://;
        my $name = $self->{name};
        $self->{native} = (-f "${name}_${version}.diff.gz" ? 0 : 1);
    }
    return $self->{native};
}

# Returns a hash of binaries to the package type, assuming a type of deb
# unless the package type field is present.
sub binaries {
    my ($self) = @_;
    return $self->{binaries} if exists $self->{binaries};
    my %binaries;
    opendir(BINPKGS, 'control') or fail("can't open control directory: $!");
    for my $package (readdir BINPKGS) {
        next if $binpkg =~ /^\.\.?$/;
        my $type = $self->binary_field($package, 'xc-package-type') || 'deb';
        $binaries{$package} = lc $type;
    }
    closedir BINPKGS;
    $self->{binaries} = \%binaries;
    return $self->{binaries};
}

# Returns the value of a control field for a binary package or the empty
# string if that control field isn't present.  This does not implement
# inheritance from the settings in the source stanza.
sub binary_field {
    my ($self, $package, $field) = @_;
    return $self->{binary_field}{$package}{$field}
        if exists $self->{binary_field}{$package}{$field};
    my $value = '';
    if (-f "control/$package/$field") {
        $value = slurp_entire_file("control/$package/$field");
        chomp $value;
    }
    $self->{binary_field}{$package}{$field} = $value;
    return $self->{binary_field}{$package}{$field};
}

=head1 NAME

Lintian::Collect::Source - Lintian interface to source package data collection

=head1 SYNOPSIS

    my $collect = Lintian::Collect->new($name, $type);
    if ($collect->native) {
        print "Package is native\n";
    }

=head1 DESCRIPTION

Lintian::Collect::Source provides an interface to package data for source
packages.  It implements data collection methods specific to source
packages.

This module is in its infancy.  Most of Lintian still reads all data from
files in the laboratory whenever that data is needed and generates that
data via collect scripts.  The goal is to eventually access all data about
source packages via this module so that the module can cache data where
appropriate and possibly retire collect scripts in favor of caching that
data in memory.

=head1 CLASS METHODS

=item new(PACKAGE)

Creates a new Lintian::Collect::Source object.  Currently, PACKAGE is
ignored.  Normally, this method should not be called directly, only via
the Lintian::Collect constructor.

=back

=head1 INSTANCE METHODS

In addition to the instance methods listed below, all instance methods
documented in the Lintian::Collect module are also available.

=over 4

=item binaries()

Returns a hash reference with the binary package names as keys and the
Package-Type as value (which should be either C<deb> or C<udeb>
currently).  The source-control-file collection script must have been run
to parse the F<debian/control> file and put the fields in the F<control>
directory in the lab.

=item binary_field(PACKAGE, FIELD)

Returns the content of the field FIELD for the binary package PACKAGE in
the F<debian/control> file, or an empty string if that field isn't set.
Inheritance of field values from the source section of the control file is
not implemented.  Only the literal value of the field is returned.

The source-control-file collection script must have been run to parse the
F<debian/control> file and put the fields in the F<control> directory in
the lab.

=item changelog()

Returns the changelog of the source package as a Parse::DebianChangelog
object, or undef if the changelog is a symlink or doesn't exist.  The
debfiles collection script must have been run to create the changelog
file, which this method expects to find in F<debfiles/changelog>.

=item native()

Returns true if the source package is native and false otherwise.

=back

=head1 AUTHOR

Originally written by Russ Allbery <rra@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1), Lintian::Collect(3)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 ts=4 et shiftround

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
use warnings;
use base 'Lintian::Collect::Package';

use Lintian::Relation;
use Parse::DebianChangelog;

use Util;

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
# sub changelog Needs-Info debfiles
sub changelog {
    my ($self) = @_;
    return $self->{changelog} if exists $self->{changelog};
    my $base_dir = $self->base_dir();
    if (-l "$base_dir/debfiles/changelog" ||
        ! -f "$base_dir/debfiles/changelog") {
        $self->{changelog} = undef;
    } else {
        my %opts = (infile => "$base_dir/debfiles/changelog", quiet => 1);
        $self->{changelog} = Parse::DebianChangelog->init(\%opts);
    }
    return $self->{changelog};
}

# Returns whether the package is a native package.  For everything except
# format 3.0 (quilt) packages, we base this on whether we have a Debian
# *.diff.gz file.  3.0 (quilt) packages are always non-native.  Returns true
# if the package is native and false otherwise.
# sub native Needs-Info <>
sub native {
    my ($self) = @_;
    return $self->{native} if exists $self->{native};
    my $format = $self->field('format');
    if ($format =~ m/^\s*2\.0\s*$/o or $format =~ m/^\s*3\.0\s+\(quilt\)\s*$/o) {
        $self->{native} = 0;
    } elsif ($format =~ m/^\s*3\.0\s+\(native\)\s*$/o) {
        $self->{native} = 1;
    } else {
        my $version = $self->field('version');
        my $base_dir = $self->base_dir();
        $version =~ s/^\d+://;
        my $name = $self->{name};
        $self->{native} = (-f "$base_dir/${name}_${version}.diff.gz" ? 0 : 1);
    }
    return $self->{native};
}

# Returns a hash of binaries to the package type, assuming a type of deb
# unless the package type field is present.
sub binaries {
    my ($self) = @_;
    return $self->{binaries} if exists $self->{binaries};
    my %binaries;
    my $base_dir = $self->base_dir();
    # sub binaries Needs-Info source-control-file
    opendir(BINPKGS, "$base_dir/control") or fail("can't open control directory: $!");
    for my $package (readdir BINPKGS) {
        next if $package =~ /^\.\.?$/;
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
    my $base_dir = $self->base_dir();
    # sub binary_field Needs-Info source-control-file
    if (-f "$base_dir/control/$package/$field") {
        $value = slurp_entire_file("$base_dir/control/$package/$field");
        chomp $value;
    }
    $self->{binary_field}{$package}{$field} = $value;
    return $self->{binary_field}{$package}{$field};
}

# Return a Lintian::Relation object for the given relationship field in a
# binary package.  In addition to all the normal relationship fields, the
# following special field names are supported:  all (pre-depends, depends,
# recommends, and suggests), strong (pre-depends and depends), and weak
# (recommends and suggests).
sub binary_relation {
    my ($self, $package, $field) = @_;
    $field = lc $field;
    return $self->{binary_relation}->{$package}->{$field}
        if exists $self->{binary_relation}->{$package}->{$field};

    my %special = (all    => [ qw(pre-depends depends recommends suggests) ],
                   strong => [ qw(pre-depends depends) ],
                   weak   => [ qw(recommends suggests) ]);
    my $result;
    if ($special{$field}) {
        my $merged;
        for my $f (@{ $special{$field} }) {
	    # sub binary_relation Needs-Info :binary_field
            my $value = $self->binary_field($f);
            $merged .= ', ' if (defined($merged) and defined($value));
            $merged .= $value if defined($value);
        }
        $result = $merged;
    } else {
        my %known = map { $_ => 1 }
            qw(pre-depends depends recommends suggests enhances breaks
               conflicts provides replaces);
        croak("unknown relation field $field") unless $known{$field};
        my $value = $self->binary_field($field);
        $result = $value if defined($value);
    }
    $result = Lintian::Relation->new($result);
    $self->{binary_relation}->{$package}->{$field} = $result;
    return $self->{binary_relation}->{$field};
}


# Return a Lintian::Relation object for the given build relationship
# field.  In addition to all the normal build relationship fields, the
# following special field names are supported:  build-depends-all
# (build-depends and build-depends-indep) and build-conflicts-all
# (build-conflicts and build-conflicts-indep).
# sub relation Needs-Info fields
sub relation {
    my ($self, $field) = @_;
    $field = lc $field;
    return $self->{relation}->{$field} if exists $self->{relation}->{$field};

    my $result;
    if ($field =~ /^build-(depends|conflicts)-all$/) {
        my $type = $1;
        my $merged;
        for my $f ("build-$type", "build-$type-indep") {
            my $value = $self->field($f);
            $merged .= ', ' if (defined($merged) and defined($value));
            $merged .= $value if defined($value);
        }
        $result = $merged;
    } elsif ($field =~ /^build-(depends|conflicts)(-indep)?$/) {
        my $value = $self->field($field);
        $result = $value if defined($value);
    } else {
        croak("unknown relation field $field");
    }
    $self->{relation}->{$field} = Lintian::Relation->new($result);
    return $self->{relation}->{$field};
}

# Similar to relation(), return a Lintian::Relation object for the given build
# relationship field, but ignore architecture restrictions.  It supports the
# same special field names.
# sub relation_noarch Needs-Info fields
sub relation_noarch {
    my ($self, $field) = @_;
    $field = lc $field;
    return $self->{relation_noarch}->{$field}
        if exists $self->{relation_noarch}->{$field};

    my $result;
    if ($field =~ /^build-(depends|conflicts)-all$/) {
        my $type = $1;
        my $merged;
        for my $f ("build-$type", "build-$type-indep") {
            my $value = $self->field($f);
            $merged .= ', ' if (defined($merged) and defined($value));
            $merged .= $value if defined($value);
        }
        $result = $merged;
    } elsif ($field =~ /^build-(depends|conflicts)(-indep)?$/) {
        my $value = $self->field($field);
        $result = $value if defined($value);
    } else {
        croak("unknown relation field $field");
    }
    $self->{relation_noarch}->{$field}
        = Lintian::Relation->new_noarch($result);
    return $self->{relation_noarch}->{$field};
}

# Like unpacked except this only returns the contents of debian/ from a source
# package.
#
# sub debfiles Needs-Info debfiles
sub debfiles {
    my ($self, $file) = @_;
    return $self->_fetch_extracted_dir('debfiles', 'debfiles', $file);
}

=head1 NAME

Lintian::Collect::Source - Lintian interface to source package data collection

=head1 SYNOPSIS

    my ($name, $type) = ('foobar', 'source');
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

=over 4

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

=item binary_relation(PACKAGE, FIELD)

Returns a Lintian::Relation object for the specified FIELD in the binary
package PACKAGE in the F<debian/control> file.  FIELD should be one of the
possible relationship fields of a Debian package or one of the following
special values:

=over 4

=item all

The concatenation of Pre-Depends, Depends, Recommends, and Suggests.

=item strong

The concatenation of Pre-Depends and Depends.

=item weak

The concatenation of Recommends and Suggests.

=back

If FIELD isn't present in the package, the returned Lintian::Relation
object will be empty (always satisfied and implies nothing).

Any substvars in F<debian/control> will be represented in the returned
relation as packages named after the substvar.

=item changelog()

Returns the changelog of the source package as a Parse::DebianChangelog
object, or undef if the changelog is a symlink or doesn't exist.  The
debfiles collection script must have been run to create the changelog
file, which this method expects to find in F<debfiles/changelog>.

=item native()

Returns true if the source package is native and false otherwise.

=item relation(FIELD)

Returns a Lintian::Relation object for the given build relationship field
FIELD.  In addition to the normal build relationship fields, the
following special field names are supported:

=over 4

=item build-depends-all

The concatenation of Build-Depends and Build-Depends-Indep.

=item build-conflicts-all

The concatenation of Build-Conflicts and Build-Conflicts-Indep.

=back

If FIELD isn't present in the package, the returned Lintian::Relation
object will be empty (always satisfied and implies nothing).

=item relation_noarch(FIELD)

The same as relation(), but ignores architecture restrictions in the
FIELD field.

=back

=head1 AUTHOR

Originally written by Russ Allbery <rra@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1), Lintian::Collect(3), Lintian::Relation(3)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 ts=4 et shiftround

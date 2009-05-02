# -*- perl -*-
# Lintian::Collect::Binary -- interface to binary package data collection

# Copyright (C) 2008, 2009 Russ Allbery
# Copyright (C) 2008 Frank Lichtenheld
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

package Lintian::Collect::Binary;

use strict;
use warnings;
use base 'Lintian::Collect';

use Lintian::Relation;
use Carp qw(croak);
use Parse::DebianChangelog;

use Util;

# Initialize a new binary package collect object.  Takes the package name,
# which is currently unused.
sub new {
    my ($class, $pkg) = @_;
    my $self = {};
    bless($self, $class);
    return $self;
}

# Returns whether the package is a native package according to
# its version number
# sub native Needs-Info <>
sub native {
    my ($self) = @_;
    return $self->{native} if exists $self->{native};
    my $version = $self->field('version');
    $self->{native} = ($version !~ m/-/);
    return $self->{native};
}

# Get the changelog file of a binary package as a Parse::DebianChangelog
# object.  Returns undef if the changelog file couldn't be found.
sub changelog {
    my ($self) = @_;
    return $self->{changelog} if exists $self->{changelog};
    # sub changelog Needs-Info changelog-file
    if (-l 'changelog' || ! -f 'changelog') {
        $self->{changelog} = undef;
    } else {
        my %opts = (infile => 'changelog', quiet => 1);
        $self->{changelog} = Parse::DebianChangelog->init(\%opts);
    }
    return $self->{changelog};
}

# Returns the information from the indices
# FIXME: should maybe return an object
# sub index Needs-Info <>
sub index {
    my ($self) = @_;
    return $self->{index} if exists $self->{index};

    my (%idx, %dir_counts);
    open my $idx, '<', "index"
        or fail("cannot open index file index: $!");
    open my $num_idx, '<', "index-owner-id"
        or fail("cannot open index file index-owner-id: $!");
    while (<$idx>) {
        chomp;

        my (%file, $perm, $owner, $name);
        ($perm,$owner,$file{size},$file{date},$file{time},$name) =
            split(' ', $_, 6);
        $file{operm} = perm2oct($perm);
        $file{type} = substr $perm, 0, 1;

        my $numeric = <$num_idx>;
        chomp $numeric;
        fail("cannot read index file index-owner-id") unless defined $numeric;
        my ($owner_id, $name_chk) = (split(' ', $numeric, 6))[1, 5];
        fail("mismatching contents of index files: $name $name_chk")
            if $name ne $name_chk;

        ($file{owner}, $file{group}) = split '/', $owner, 2;
        ($file{uid}, $file{gid}) = split '/', $owner_id, 2;

        $name =~ s,^\./,,;
        if ($name =~ s/ link to (.*)//) {
            $file{type} = 'h';
            $file{link} = $1;
            $file{link} =~ s,^\./,,;
        } elsif ($file{type} eq 'l') {
            ($name, $file{link}) = split ' -> ', $name, 2;
        }
        $file{name} = $name;

        # count directory contents:
        $dir_counts{$name} ||= 0 if $file{type} eq 'd';
        $dir_counts{$1} = ($dir_counts{$1} || 0) + 1
            if $name =~ m,^(.+/)[^/]+/?$,;

        $idx{$name} = \%file;
    }
    foreach my $file (keys %idx) {
        if ($dir_counts{$idx{$file}->{name}}) {
            $idx{$file}->{count} = $dir_counts{$idx{$file}->{name}};
        }
    }
    $self->{index} = \%idx;

    return $self->{index};
}

# Returns the information from collect/file-info
sub file_info {
    my ($self) = @_;
    return $self->{file_info} if exists $self->{file_info};

    my %file_info;
    # sub file_info Needs-Info file-info
    open(my $idx, '<', "file-info")
        or fail("cannot open file-info: $!");
    while (<$idx>) {
        chomp;

        m/^(.+?):\s+(.*)$/o
            or fail("an error in the file pkg is preventing lintian from checking this package: $_");
        my ($file, $info) = ($1,$2);

        $file =~ s,^\./,,o;
        $file =~ s,/+$,,o;

        $file_info{$file} = $info;
    }
    close $idx;
    $self->{file_info} = \%file_info;

    return $self->{file_info};
}

sub scripts {
    my ($self) = @_;
    return $self->{scripts} if exists $self->{scripts};

    my %scripts;
    # sub scripts Needs-Info scripts
    open(SCRIPTS, '<', "scripts")
	or fail("cannot open scripts file: $!");
    while (<SCRIPTS>) {
	chomp;
	my (%file, $name);

	m/^(env )?(\S*) (.*)$/o
	    or fail("bad line in scripts file: $_");
	($file{calls_env}, $file{interpreter}, $name) = ($1, $2, $3);

	$name =~ s,^\./,,o;
	$name =~ s,/+$,,o;
	$file{name} = $name;
	$scripts{$name} = \%file;
    }
    close SCRIPTS;
    $self->{scripts} = \%scripts;

    return $self->{scripts};
}


# Returns the information from collect/objdump-info
sub objdump_info {
    my ($self) = @_;
    return $self->{objdump_info} if exists $self->{objdump_info};

    my %objdump_info;
    my ($dynsyms, $file);
    # sub objdump_info Needs-Info objdump-info
    open(my $idx, '<', "objdump-info")
        or fail("cannot open objdump-info: $!");
    while (<$idx>) {
        chomp;

        next if m/^\s*$/o;

        if (m,^-- \./(\S+)\s*$,o) {
            if ($file) {
                $objdump_info{$file->{name}} = $file;
            }
            $file = { name => $1 };
            $dynsyms = 0;
        } elsif ($dynsyms) {
            # The .*? near the end is added because a number of optional fields
            # might be printed.  The symbol name should be the last word.
            if (m/^[0-9a-fA-F]+.{6}\w\w?\s+(\S+)\s+[0-9a-zA-Z]+\s+(\S+)\s+(\S+)$/){
                my ($foo, $sec, $sym) = ($1, $2, $3);
                push @{$file->{SYMBOLS}}, [ $foo, $sec, $sym ];

		if ($foo eq '.text' and $sec eq 'Base' and $sym eq 'caml_main') {
		    $file->{OCAML} = 1;
		}
            }
        } else {
            if (m/^\s*NEEDED\s*(\S+)/o) {
                push @{$file->{NEEDED}}, $1;
            } elsif (m/^\s*RPATH\s*(\S+)/o) {
                foreach (split m/:/, $1) {
                    $file->{RPATH}{$_}++;
                }
            } elsif (m/^\s*SONAME\s*(\S+)/o) {
                push @{$file->{SONAME}}, $1;
            } elsif (m/^\s*\d+\s+\.comment\s+/o) {
                $file->{COMMENT_SECTION} = 1;
            } elsif (m/^\s*\d+\s+\.note\s+/o) {
                $file->{NOTE_SECTION} = 1;
            } elsif (m/^DYNAMIC SYMBOL TABLE:/) {
                $dynsyms = 1;
            } elsif (m/^objdump: (.*?): File format not recognized$/) {
                push @{$file->{NOTES}}, "File format not recognized";
            } elsif (m/^objdump: (.*?): File truncated$/) {
                push @{$file->{NOTES}}, "File truncated";
            } elsif (m/^objdump: \.(.*?): Packed with UPX$/) {
                push @{$file->{NOTES}}, "Packed with UPX";
            } elsif (m/objdump: \.(.*?): Invalid operation$/) {
                # Don't anchor this regex since it can be interspersed with other
                # output and hence not on the beginning of a line.
                push @{$file->{NOTES}}, "Invalid operation";
            } elsif (m/CXXABI/) {
                $file->{CXXABI} = 1;
            } elsif (m%Requesting program interpreter:\s+/lib/klibc-\S+\.so%) {
                $file->{KLIBC} = 1;
	    } elsif (m/^\s*TEXTREL\s/o) {
		$file->{TEXTREL} = 1;
	    } elsif (m/^\s*INTERP\s/) {
		$file->{INTERP} = 1;
	    } elsif (m/^\s*STACK\s/) {
		$file->{STACK} = 0;
	    } else {
		if (defined $file->{STACK} and $file->{STACK} eq 0) {
		    m/\sflags\s+(\S+)/o;
		    $file->{STACK} = $1;
		} else {
		    $file->{OTHER_DATA} = 1;
		}
	    }
	}
    }
    if ($file) {
        $objdump_info{$file->{name}} = $file;
    }
    $self->{objdump_info} = \%objdump_info;

    return $self->{objdump_info};
}

# Return a Lintian::Relation object for the given relationship field.  In
# addition to all the normal relationship fields, the following special
# field names are supported: all (pre-depends, depends, recommends, and
# suggests), strong (pre-depends and depends), and weak (recommends and
# suggests).
# sub relation Needs-Info <>
sub relation {
    my ($self, $field) = @_;
    $field = lc $field;
    return $self->{relation}->{$field} if exists $self->{relation}->{$field};

    my %special = (all    => [ qw(pre-depends depends recommends suggests) ],
                   strong => [ qw(pre-depends depends) ],
                   weak   => [ qw(recommends suggests) ]);
    my $result;
    if ($special{$field}) {
        my $merged;
        for my $f (@{ $special{$field} }) {
            my $value = $self->field($f);
            $merged .= ', ' if (defined($merged) and defined($value));
            $merged .= $value if defined($value);
        }
        $result = $merged;
    } else {
        my %known = map { $_ => 1 }
            qw(pre-depends depends recommends suggests enhances breaks
               conflicts provides replaces);
        croak("unknown relation field $field") unless $known{$field};
        my $value = $self->field($field);
        $result = $value if defined($value);
    }
    $self->{relation}->{$field} = Lintian::Relation->new($result);
    return $self->{relation}->{$field};
}

=head1 NAME

Lintian::Collect::Binary - Lintian interface to binary package data collection

=head1 SYNOPSIS

    my ($name, $type) = ('foobar', 'binary');
    my $collect = Lintian::Collect->new($name, $type);
    if ($collect->native) {
        print "Package is native\n";
    }

=head1 DESCRIPTION

Lintian::Collect::Binary provides an interface to package data for binary
packages.  It implements data collection methods specific to binary
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

Creates a new Lintian::Collect::Binary object.  Currently, PACKAGE is
ignored.  Normally, this method should not be called directly, only via
the Lintian::Collect constructor.

=back

=head1 INSTANCE METHODS

In addition to the instance methods listed below, all instance methods
documented in the Lintian::Collect module are also available.

=over 4

=item changelog()

Returns the changelog of the binary package as a Parse::DebianChangelog
object, or undef if the changelog doesn't exist.  The changelog-file
collection script must have been run to create the changelog file, which
this method expects to find in F<changelog>.

=item native()

Returns true if the binary package is native and false otherwise.
Nativeness will be judged by its version number.

=item index()

Returns a reference to an array of hash references with content
information about the binary package.  Each hash may have the
following keys:

=over 4

=item name

Name of the index entry without leading slash.

=item owner

=item group

=item uid

=item gid

The former two are in string form and may depend on the local system,
the latter two are the original numerical values as saved by tar.

=item date

Format "YYYY-MM-DD".

=item time

Format "hh:mm".

=item type

Entry type as one character.

=item operm

Entry permissions as octal number.

=item size

Entry size in bytes.  Note that tar(1) lists the size of directories as
0 (so this is what you will get) contrary to what ls(1) does.

=item link

If the entry is either a hardlink or symlink, contains the target of the
link.

=item count

If the entry is a directory, contains the number of other entries this
directory contains.

=back

=item relation(FIELD)

Returns a Lintian::Relation object for the specified FIELD, which should
be one of the possible relationship fields of a Debian package or one of
the following special values:

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

=back

=head1 AUTHOR

Originally written by Frank Lichtenheld <djpig@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1), Lintian::Collect(3), Lintian::Relation(3)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 ts=4 et shiftround

# -*- perl -*-
# Lintian::Collect::Binary -- interface to binary package data collection

# Copyright (C) 2008, 2009 Russ Allbery
# Copyright (C) 2008 Frank Lichtenheld
# Copyright (C) 2012 Kees Cook
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
use base 'Lintian::Collect::Package';

use Lintian::Relation;
use Carp qw(croak);
use Parse::DebianChangelog;

use Lintian::Util qw(fail open_gz parse_dpkg_control);

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
    if (defined $version) {
        $self->{native} = ($version !~ m/-/);
    } else {
        # We do not know, but assume it to non-native as it is
        # the most likely case.
        $self->{native} = 0;
    }
    return $self->{native};
}

# Get the changelog file of a binary package as a Parse::DebianChangelog
# object.  Returns undef if the changelog file couldn't be found.
sub changelog {
    my ($self) = @_;
    return $self->{changelog} if exists $self->{changelog};
    my $dch = $self->lab_data_path ('changelog');
    # sub changelog Needs-Info changelog-file
    if (-l $dch || ! -f $dch) {
        $self->{changelog} = undef;
    } else {
        my %opts = (infile => $dch, quiet => 1);
        $self->{changelog} = Parse::DebianChangelog->init(\%opts);
    }
    return $self->{changelog};
}

# Like unpacked except this returns the contents of the control.tar.gz
# in an unpacked directory.
#
# sub control Needs-Info bin-pkg-control
sub control {
    my ($self, $file) = @_;
    return $self->_fetch_extracted_dir('control', 'control', $file);
}

# Like index except it returns the index for the control/metadata of
# binary package.
#
# sub control_index Needs-Info bin-pkg-control
sub control_index {
    my ($self, $file) = @_;
    return $self->_fetch_index_data ('control-index', 'control-index',
                                     undef, $file);
}

# Like sorted_index except it returns the index for the control/metadata of
# binary package.
#
# sub sorted_control_index Needs-Info bin-pkg-control
sub sorted_control_index {
    my ($self) = @_;
    # control_index does all our work for us, so call it if
    # sorted_control_index has not been created yet.
    $self->control_index ('') unless exists $self->{'sorted_control-index'};
    return @{ $self->{'sorted_control-index'} };
}

# Returns a handle with the strings in a given binary file (as computed
# by coll/strings)
#
# sub strings Needs-Info strings
sub strings {
    my ($self, $file) = @_;
    my $real = $self->_fetch_extracted_dir ('strings', 'strings', $file);
    if ( not -f "${real}.gz" ) {
        open my $fd, '<', '/dev/null';
        return $fd;
    }
    my $fd = open_gz ("$real.gz") or fail "open ${file}.gz: $!";
    return $fd;
}

# Returns the md5sums as calculated by the md5sums collection
#  sub md5sums Needs-Info md5sums
sub md5sums {
    my ($self) = @_;
    return $self->{md5sums} if exists $self->{md5sums};
    my $md5f = $self->lab_data_path ('md5sums');
    my $result = {};

    # read in md5sums info file
    open my $fd, '<', $md5f
        or fail "cannot open $md5f info file: $!";
    while (my $line = <$fd>) {
        chop($line);
        next if $line =~ m/^\s*$/o;
        $line =~ m/^(\S+)\s*(\S.*)$/o
            or fail "syntax error in $md5f info file: $line";
        my $zzsum = $1;
        my $zzfile = $2;
        $zzfile =~ s,^(?:\./)?,,o;
        $result->{$zzfile} = $zzsum;
    }
    close($fd);
    $self->{md5sums} = $result;
    return $result;
}

sub scripts {
    my ($self) = @_;
    return $self->{scripts} if exists $self->{scripts};
    my $scrf = $self->lab_data_path ('scripts');
    my %scripts;
    local $_;
    # sub scripts Needs-Info scripts
    open SCRIPTS, '<', $scrf
        or fail "cannot open scripts $scrf: $!";
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
    my $objf = $self->lab_data_path ('objdump-info.gz');
    my %objdump_info;
    my ($dynsyms, $file);
    local $_;
    # sub objdump_info Needs-Info objdump-info
    my $fd = open_gz ($objf)
        or fail "cannot open $objf: $!";
    foreach my $pg (parse_dpkg_control ($fd)) {
        my %info = (
            'PH' => {},
            'SH' => {},
            'NOTES'  => [],
            'NEEDED' => [],
            'RPATH'  => {},
            'SONAME' => [],
        );
        $info{'ERRORS'} = lc ($pg->{'broken'}//'no') eq 'yes' ? 1 : 0;
        $info{'UPX'} = lc ($pg->{'upx'}//'no') eq 'yes' ? 1 : 0;
        $info{'BAD-DYNAMIC-TABLE'} = lc ($pg->{'bad-dynamic-table'}//'no') eq 'yes' ? 1 : 0;
        foreach my $symd (split m/\s*\n\s*/, $pg->{'dynamic-symbols'}//'') {
            next unless $symd;
            if ($symd =~ m/^\s*(\S+)\s+(?:(\S+)\s+)?(\S+)$/){
                # $ver is not always there
                my ($sec, $ver, $sym) = ($1, $2, $3);
                $ver //= '';
                push @{ $info{'SYMBOLS'} }, [ $sec, $ver, $sym ];
            }
        }
        foreach my $data (split m/\s*\n\s*/, $pg->{'section-headers'}//'') {
            next unless $data;
            my (undef, $section) = split m/\s++/, $data;
            $info{'SH'}->{$section}++;
        }
        foreach my $data (split m/\s*\n\s*/, $pg->{'program-headers'}//'') {
            next unless $data;
            my ($header, @vals) = split m/\s++/, $data;
            $info{'PH'}->{$header} = {};
            foreach my $extra (@vals) {
                my ($opt, $val) = split m/=/, $extra;
                $info{'PH'}->{$header}->{$opt} = $val;
                if ($opt eq 'interp' and $header eq 'INTERP') {
                    $info{'INTERP'} = $val;
                }
            }
        }
        foreach my $data (split m/\s*\n\s*/, $pg->{'dynamic-section'}//'') {
            next unless $data;
            # Here we just need RPATH and NEEDS, so ignore the rest for now
            my ($header, $val) = split m/\s++/, $data;
            if ($header eq 'RPATH') {
                $info{$header}->{$val} = 1;
            } elsif ($header eq 'NEEDED' or $header eq 'SONAME') {
                push @{ $info{$header} }, $val;
            }
        }

        $objdump_info{$pg->{'filename'}} = \%info;
    }
    $self->{objdump_info} = \%objdump_info;

    close $fd;

    return $self->{objdump_info};
}


# Returns the information from collect/hardening-info
# sub hardening_info Needs-Info hardening-info
sub hardening_info {
    my ($self) = @_;
    return $self->{hardening_info} if exists $self->{hardening_info};
    my $hardf = $self->lab_data_path ('hardening-info');
    my %hardening_info;
    my ($file);
    local $_;
    open my $idx, '<', $hardf
        or fail "cannot open $hardf: $!";
    while (<$idx>) {
        chomp;

        if (m,^([^:]+):(?:\./)?(.*)$,) {
            my ($tag, $file) = ($1, $2);
            push(@{$hardening_info{$file}}, $tag);
        }
    }

    $self->{hardening_info} = \%hardening_info;

    return $self->{hardening_info};
}


# Returns the information from collect/objdump-info
# sub java_info Needs-Info java-info
sub java_info {
    my ($self) = @_;
    return $self->{java_info} if exists $self->{java_info};
    my $javaf = $self->lab_data_path ('java-info.gz');
    my %java_info;
    if ( ! -f $javaf ) {
        # no java-info.gz => no jar files to collect data.  Just
        # return an empty hash ref.
        $self->{java_info} = \%java_info;
        return $self->{java_info};
    }
    my $idx = open_gz ($javaf)
        or fail "cannot open $javaf: $!";
    my $file;
    my $file_list;
    my $manifest = 0;
    local $_;
    while (<$idx>) {
        chomp;
        next if m/^\s*$/o;

        if (m#^-- MANIFEST: (?:\./)?(?:.+)$#o) {
            # TODO: check $file == $1 ?
            $java_info{$file}->{manifest} = {};
            $manifest = $java_info{$file}->{manifest};
            $file_list = 0;
        }
        elsif (m#^-- (?:\./)?(.+)$#o) {
            $file = $1;
            $java_info{$file}->{files} = {};
            $file_list = $java_info{$file}->{files};
            $manifest = 0;
        }
        else {
            if($manifest && m#^  (\S+):\s(.*)$#o) {
                $manifest->{$1} = $2;
            }
            elsif ($file_list) {
                my ($fname, $clmajor) = (m#^(.*):\s*([-\d]+)$#);
                $file_list->{$fname} = $clmajor;
            }

        }
    }
    $self->{java_info} = \%java_info;
    return $self->{java_info};
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
        $result = Lintian::Relation->and (
            map { $self->relation ($_) } @{ $special{$field} }
        );
    } else {
        my %known = map { $_ => 1 }
            qw(pre-depends depends recommends suggests enhances breaks
               conflicts provides replaces);
        croak("unknown relation field $field") unless $known{$field};
        my $value = $self->field($field);
        $result = Lintian::Relation->new ($value);
    }
    $self->{relation}->{$field} = $result;
    return $self->{relation}->{$field};
}

# Returns a truth value if the package appears to be transitional package.
# - this is based on the package description.
# sub is_transitional Needs-Info <>
sub is_transitional {
    my ($self) = @_;
    my $desc = $self->field ('description')//'';
    return $desc =~ m/transitional package/;
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
binary packages via this module so that the module can cache data where
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

=item java_info()

Returns a hash containing information about JAR files found in binary
packages, in the form I<file name> -> I<info>, where I<info> is a hash
containing the following keys:

=over 4

=item manifest

A hash containing the contents of the JAR file manifest. For instance,
to find the classpath of I<$file>, you could use:

 my $cp = $info->java_info()->{$file}->{'Class-Path'};

=item files

the list of the files contained in the archive.

=back

=item native()

Returns true if the binary package is native and false otherwise.
Nativeness will be judged by its version number.

If the version number is absent, this will return false (as
native packages are a lot rarer than non-native ones).

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

=item is_transitional

Returns a truth value if the package appears to be a transitional
package.

This is based on the package's description.

=item strings (FILE)

Returns an open handle, which will read the data from coll/strings for
FILE.

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
# vim: syntax=perl sw=4 sts=4 sr et

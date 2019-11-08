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
use autodie;

use BerkeleyDB;
use Carp qw(croak);
use List::Util qw(any);
use MLDBM qw(BerkeleyDB::Btree Storable);
use Path::Tiny;

use Lintian::Deb822Parser qw(parse_dpkg_control);
use Lintian::Relation;
use Lintian::Util qw(open_gz get_file_checksum strip rstrip);

use constant EMPTY => q{};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Collect::Binary - Lintian interface to binary package data collection

=head1 SYNOPSIS

    my ($name, $type, $dir) = ('foobar', 'binary', '/path/to/lab-entry');
    my $collect = Lintian::Collect::Binary->new($name);

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

Native heuristics are only available in source packages.

=head1 INSTANCE METHODS

In addition to the instance methods listed below, all instance methods
documented in the L<Lintian::Collect> and the
L<Lintian::Info::Package> modules are also available.

=over 4

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

Needs-Info requirements for using I<index>: unpacked

=cut

sub index {
    my ($self, $file) = @_;
    if (my $cache = $self->{'index'}) {
        return $cache->{$file}
          if exists($cache->{$file});
        return;
    }
    my $load_info = {
        'field' => 'index',
        'index_file' => 'index',
        'index_owner_file' => 'index-owner-id',
        'fs_root_sub' => 'unpacked',
        'has_anchored_root_dir' => 0,
        'file_info_sub' => 'file_info',
    };
    return $self->_fetch_index_data($load_info, $file);
}

=item control ([FILE])

B<This method is deprecated>.  Consider using
L</control_index_resolved_path(PATH)> instead, which returns
L<Lintian::Path> objects.

Returns the path to FILE in the control.tar.gz.  FILE must be either a
L<Lintian::Path> object (>= 2.5.13~) or a string denoting the
requested path.  In the latter case, the path must be relative to the
root of the control.tar.gz member and should be normalized.

It is not permitted for FILE to be C<undef>.  If the "root" dir is
desired either invoke this method without any arguments at all, pass
it the correct L<Lintian::Path> or the empty string.

To get a list of entries in the control.tar.gz or the file meta data
of the entries (as L<path objects|Lintian::Path>), see
L</sorted_control_index> and L</control_index (FILE)>.

The caveats of L<unpacked|Lintian::Info::Package/unpacked ([FILE])>
also apply to this method.  However, as the control.tar.gz is not
known to contain symlinks, a simple file type check is usually enough.

Needs-Info requirements for using I<control>: bin-pkg-control

=cut

sub control {
    ## no critic (Subroutines::RequireArgUnpacking)
    # - see L::Collect::unpacked for why
    my $self = shift(@_);
    my $f = $_[0] // '';

    warnings::warnif(
        'deprecated',
        '[deprecated] The control method is deprecated.  '
          . "Consider using \$info->control_index_resolved_path('$f') instead."
          . '  Called' # warnif appends " at <...>"
    );
    return $self->_fetch_extracted_dir('control', 'control', @_);
}

=item control_index (FILE)

Returns a L<path object|Lintian::Path> to FILE in the control.tar.gz.
FILE must be relative to the root of the control.tar.gz and must be
without leading slash (or "./").  If FILE is not in the
control.tar.gz, it returns C<undef>.

To get a list of entries in the control.tar.gz, see
L</sorted_control_index>.  To actually access the underlying file
(e.g. the contents), use L</control ([FILE])>.

Note that the "root directory" (denoted by the empty string) will
always be present, even if the underlying tarball omits it.

Needs-Info requirements for using I<control_index>: bin-pkg-control

=cut

sub control_index {
    my ($self, $file) = @_;
    if (my $cache = $self->{'control_index'}) {
        return $cache->{$file}
          if exists($cache->{$file});
        return;
    }
    my $load_info = {
        'field' => 'control_index',
        'index_file' => 'control-index',
        'index_owner_file' => undef,
        'fs_root_sub' => 'control',
        # Control files are not installed relative to the system root.
        # Accordingly, we forbid absolute paths and symlinks..
        'has_anchored_root_dir' => 0,
    };
    return $self->_fetch_index_data($load_info, $file);
}

=item sorted_control_index

Returns a sorted array of file names listed in the control.tar.gz.
The names will not have a leading slash (or "./") and can be passed
to L</control ([FILE])> or L</control_index (FILE)> as is.

The array will not contain the entry for the "root" of the
control.tar.gz.

Needs-Info requirements for using I<sorted_control_index>: L<Same as control_index|/control_index (FILE)>

=cut

sub sorted_control_index {
    my ($self) = @_;
    # control_index does all our work for us, so call it if
    # sorted_control_index has not been created yet.
    $self->control_index('') unless exists($self->{'sorted_control_index'});
    return @{ $self->{'sorted_control_index'} };
}

=item control_index_resolved_path(PATH)

Resolve PATH (relative to the root of the package) and return the
L<entry|Lintian::Path> denoting the resolved path.

The resolution is done using
L<resolve_path|Lintian::Path/resolve_path([PATH])>.

Needs-Info requirements for using I<control_index_resolved_path>: L<Same as control_index|/control_index (FILE)>

=cut

sub control_index_resolved_path {
    my ($self, $path) = @_;
    return $self->control_index('')->resolve_path($path);
}

=item strings (FILE)

Returns an open handle, which will read the data from coll/strings for
FILE.  If coll/strings did not collect any strings about FILE, this
returns an open read handle with no content.

Caller is responsible for closing the handle either way.

Needs-Info requirements for using I<strings>: strings

=cut

sub strings {
    my ($self, $file) = @_;
    my $real = $self->_fetch_extracted_dir('strings', 'strings', "${file}.gz");
    if (not -f $real) {
        open(my $fd, '<', '/dev/null');
        return $fd;
    }
    my $fd = open_gz($real);
    return $fd;
}

=item objdump_info

Returns a hashref mapping a FILE to the data collected by objdump-info
or C<undef> if no data is available for that FILE.  Data is generally
only collected for ELF files.

Needs-Info requirements for using I<objdump_info>: objdump-info

=cut

sub objdump_info {
    my ($self) = @_;

    return $self->{objdump_info}
      if exists $self->{objdump_info};

    my $objf = path($self->groupdir)->child('objdump-info.gz')->stringify;

    my %objdump_info;
    local $_;

    my $fd = open_gz($objf);

    foreach my $pg (parse_dpkg_control($fd)) {
        my %info;
        if (lc($pg->{'broken'}//'no') eq 'yes') {
            $info{'ERRORS'} = 1;
        }
        if (lc($pg->{'bad-dynamic-table'}//'no') eq 'yes') {
            $info{'BAD-DYNAMIC-TABLE'} = 1;
        }
        $info{'ELF-TYPE'} = $pg->{'elf-type'} if $pg->{'elf-type'};
        foreach my $symd (split m/\s*\n\s*/, $pg->{'dynamic-symbols'}//'') {
            next unless $symd;
            if ($symd =~ m/^\s*(\S+)\s+(?:(\S+)\s+)?(\S+)$/){
                # $ver is not always there
                my ($sec, $ver, $sym) = ($1, $2, $3);
                $ver //= '';
                push @{ $info{'SYMBOLS'} }, [$sec, $ver, $sym];
            }
        }
        foreach my $section (split m/\s*\n\s*/, $pg->{'section-headers'}//'') {
            next unless $section;
            # NB: helpers/coll/objdump-info-helper discards most
            # sections.  If you are missing a section name for a
            # check, please update helpers/coll/objdump-info-helper to
            # retrain the section name you need.
            strip($section);
            $info{'SH'}{$section} = 1;
        }
        foreach my $data (split m/\s*\n\s*/, $pg->{'program-headers'}//'') {
            next unless $data;
            my ($header, @vals) = split m/\s++/, $data;
            foreach my $extra (@vals) {
                my ($opt, $val) = split m/=/, $extra;
                if ($opt eq 'interp' and $header eq 'INTERP') {
                    $info{'INTERP'} = $val;
                } else {
                    $info{'PH'}{$header}{$opt} = $val;
                }
            }
        }
        foreach my $data (split m/\s*\n\s*/, $pg->{'dynamic-section'}//'') {
            next unless $data;
            # Here we just need RPATH and NEEDS, so ignore the rest for now
            my ($header, $val) = split(m/\s++/, $data, 2);
            if ($header eq 'RPATH' or $header eq 'RUNPATH') {
                # RPATH is like PATH
                foreach my $rpathcomponent (split(m/:/,$val)) {
                    $info{$header}{$rpathcomponent} = 1;
                }
            } elsif ($header eq 'NEEDED' or $header eq 'SONAME') {
                push @{ $info{$header} }, $val;
            } elsif ($header eq 'TEXTREL' or $header eq 'DEBUG') {
                $info{$header} = 1;
            } elsif ($header eq 'FLAGS_1') {
                for my $flag (split(m/\s++/, $val)) {
                    $info{$header}{$flag} = 1;
                }
            }
        }

        if ($pg->{'filename'} =~ m,^(.+)\(([^/\)]+)\)$,o) {
            # object file in a static lib.
            my ($lib, $obj) = ($1, $2);
            my $libentry = $objdump_info{$lib};
            if (not defined $libentry) {
                $libentry = {
                    'filename' => $lib,
                    'objects'  => [$obj],
                };
                $objdump_info{$lib} = $libentry;
            } else {
                push @{ $libentry->{'objects'} }, $obj;
            }
        }
        $objdump_info{$pg->{'filename'}} = \%info;
    }
    $self->{objdump_info} = \%objdump_info;

    close($fd);

    return $self->{objdump_info};
}

=item hardening_info

Returns a hashref mapping a FILE to its hardening issues.

NB: This is generally only useful for checks/binaries to emit the
hardening-no-* tags.

Needs-Info requirements for using I<hardening_info>: hardening-info

=cut

sub hardening_info {
    my ($self) = @_;

    return $self->{hardening_info}
      if exists $self->{hardening_info};

    my $hardf = path($self->groupdir)->child('hardening-info')->stringify;

    my %hardening_info;

    if (-e $hardf) {
        open(my $idx, '<', $hardf);
        while (my $line = <$idx>) {
            chomp($line);

            if ($line =~ m,^([^:]+):(?:\./)?(.*)$,) {
                my ($tag, $file) = ($1, $2);

                push(@{$hardening_info{$file}}, $tag);
            }
        }
        close($idx);
    }

    $self->{hardening_info} = \%hardening_info;

    return $self->{hardening_info};
}

=item relation (FIELD)

Returns a L<Lintian::Relation> object for the specified FIELD, which should
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

Needs-Info requirements for using I<relation>: L<Same as field|Lintian::Collect/field ([FIELD[, DEFAULT]])>

=cut

sub relation {
    my ($self, $field) = @_;
    $field = lc $field;
    return $self->{relation}{$field} if exists $self->{relation}{$field};

    my %special = (
        all    => [qw(pre-depends depends recommends suggests)],
        strong => [qw(pre-depends depends)],
        weak   => [qw(recommends suggests)]);
    my $result;
    if ($special{$field}) {
        $result = Lintian::Relation->and(map { $self->relation($_) }
              @{ $special{$field} });
    } else {
        my %known = map { $_ => 1 }
          qw(pre-depends depends recommends suggests enhances breaks
          conflicts provides replaces);
        croak("unknown relation field $field") unless $known{$field};
        my $value = $self->field($field);
        $result = Lintian::Relation->new($value);
    }
    $self->{relation}{$field} = $result;
    return $self->{relation}{$field};
}

=item is_pkg_class ([TYPE])

Returns a truth value if the package is the given TYPE of special
package.  TYPE can be one of "transitional", "debug" or "any-meta".
If omitted it defaults to "any-meta".  The semantics for these values
are:

=over 4

=item transitional

The package is (probably) a transitional package (e.g. it is probably
empty, just depend on stuff will eventually disappear.)

Guessed from package description.

=item any-meta

This package is (probably) some kind of meta or task package.  A meta
package is usually empty and just depend on stuff.  It will also
return a truth value for "tasks" (i.e. tasksel "tasks").

A transitional package will also match this.

Guessed from package description, section or package name.

=item debug

The package is (probably) a package containing debug symbols.

Guessed from the package name.

=item auto-generated

The package is (probably) a package generated automatically (e.g. a
dbgsym package)

Guessed from the "Auto-Built-Package" field.

=back

Needs-Info requirements for using I<is_pkg_class>: L<Same as field|Lintian::Collect/field ([FIELD[, DEFAULT]])>

=cut

{
    # Regexes to try against the package description to find metapackages or
    # transitional packages.
    my $METAPKG_REGEX= qr/meta[ -]?package|dummy|(?:dependency|empty) package/;

    sub is_pkg_class {
        my ($self, $pkg_class) = @_;
        my $desc = $self->field('description', '');
        $pkg_class //= 'any-meta';
        if ($pkg_class eq 'debug') {
            return 1 if $self->name =~ m/-dbg(?:sym)?/;
            return 0;
        }
        if ($pkg_class eq 'auto-generated') {
            return 1 if $self->field('auto-built-package');
            return 0;
        }
        return 1 if $desc =~ m/transitional package/;
        $desc = lc($desc);
        if ($pkg_class eq 'any-meta') {
            my ($section) = $self->field('section', '');
            return 1 if $desc =~ m/$METAPKG_REGEX/o;
            # Section "tasks" or "metapackages" qualifies as well
            return 1 if $section =~ m,(?:^|/)(?:tasks|metapackages)$,;
            return 1 if $self->name =~ m/^task-/;
        }
        return 0;
    }
}

=item conffiles

Returns a list of absolute filenames found for conffiles.

Needs-Info requirements for using I<conffiles>: L<Same as control_index_resolved_path|/control_index_resolved_path(PATH)>

=cut

sub conffiles {
    my ($self) = @_;

    return @{$self->{'conffiles'}}
      if exists $self->{'conffiles'};

    $self->{'conffiles'} = [];

    # read conffiles if it exists and is a file
    my $cf = $self->control_index_resolved_path('conffiles');
    return
      unless $cf && $cf->is_file && $cf->is_open_ok;

    my $fd = $cf->open;
    while (my $absolute = <$fd>) {

        chomp $absolute;

        # dpkg strips whitespace (using isspace) from the right hand
        # side of the file name.
        rstrip($absolute);

        next
          if $absolute eq EMPTY;

        # list contains absolute paths, unlike lookup
        push(@{$self->{conffiles}}, $absolute);
    }

    close($fd);

    return @{$self->{conffiles}};
}

=item is_conffile (FILE)

Returns a truth value if FILE is listed in the conffiles control file.
If the control file is not present or FILE is not listed in it, it
returns C<undef>.

Note that FILE should be the filename relative to the package root
(even though the control file uses absolute paths).  If the control
file does relative paths, they are assumed to be relative to the
package root as well (and used without warning).

Needs-Info requirements for using I<is_conffile>: L<Same as control_index_resolved_path|/control_index_resolved_path(PATH)>

=cut

sub is_conffile {
    my ($self, $file) = @_;

    unless (exists $self->{'conffiles_lookup'}) {

        $self->{'conffiles_lookup'} = {};

        for my $absolute ($self->conffiles) {

            # strip the leading slash
            my $relative = $absolute;
            $relative =~ s,^/++,,;

            # look up happens with a relative path
            $self->{conffiles_lookup}{$relative} = 1;
        }
    }

    return 1
      if exists $self->{conffiles_lookup}{$file};

    return 0;
}

=item is_non_free

Returns a truth value if the package appears to be non-free (based on
the section field; "non-free/*" and "restricted/*")

Needs-Info requirements for using I<is_non_free>: L</field ([FIELD[, DEFAULT]])>

=cut

sub is_non_free {
    my ($self) = @_;

    return 1
      if $self->field('section', 'main')
      =~ m,^(?:non-free|restricted|multiverse)/,;

    return 0;
}

=back

=head1 AUTHOR

Originally written by Frank Lichtenheld <djpig@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1), L<Lintian::Collect>, L<Lintian::Relation>

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

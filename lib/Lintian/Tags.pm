# Lintian::Tags -- manipulate and output Lintian tags

# Copyright (C) 1998-2004 Various authors
# Copyright (C) 2005 Frank Lichtenheld <frank@lichtenheld.de>
# Copyright (C) 2009 Russ Allbery <rra@debian.org>
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

package Lintian::Tags;

use strict;
use warnings;

use Lintian::Output;
use Lintian::Tag::Info;
use Util qw(fail);

use base 'Exporter';
BEGIN {
    our @EXPORT = qw(tag);
}

# The default Lintian::Tags object, set to the first one constructed and
# used by default if tag() is called without a reference to a particular
# object.
our $GLOBAL;

# Ordered lists of severities and certainties, used for display level parsing.
our @SEVERITIES  = qw(wishlist minor normal important serious);
our @CERTAINTIES = qw(wild-guess possible certain);

=head1 NAME

Lintian::Tags - Manipulate and output Lintian tags

=head1 SYNOPSIS

    my $tags = Lintian::Tags->new;
    $tags->file_start('/path/to/file', 'pkg', '1.0', 'i386', 'binary');
    $tags->file_overrides('/path/to/file', 'pkg', 'binary');
    $tags->tag('lintian-tag', 'data');
    tag('other-lintian-tag', 'data');
    my %overrides = $tags->overrides('/path/to/file');
    my %stats = $tags->statistics;
    if ($tags->displayed('lintian-tag')) {
        # do something if that tag would be displayed...
    }

=head1 DESCRIPTION

This module stores metadata about Lintian tags, stores configuration about
which tags should be displayed, handles displaying tags if appropriate,
and stores cumulative statistics about what tags have been seen.  It also
accepts override information and determines whether a tag has been
overridden, keeping override statistics.  Finally, it supports answering
metadata questions about Lintian tags, such as what references Lintian has
for that tag.

Each Lintian::Tags object has its own tag list, file list, and associated
statistics.  Separate Lintian::Tags objects can be maintained and used
independently.  However, as a convenience for Lintian's most typical use
case and for backward compatibility, the first created Lintian::Tags
object is maintained as a global default.  The tag() method can be called
as a global function instead of a method, in which case it will act on
that global default Lintian::Tags object.

=head1 CLASS METHODS

=over 4

=item new()

Creates a new Lintian::Tags object, initializes all of its internal
statistics and configuration to the defaults, and returns the newly
created object.

=cut

#'# for cperl-mode

# Each Lintian::Tags object holds the following information:
#
# current:
#     The currently selected file (not package), keying into files.
#
# display_level:
#     A two-level hash with severity as the first key and certainty as the
#     second key, with values 0 (do not show tag) or 1 (show tag).  This
#
# display_source:
#     A hash of sources to display, where source is the keyword from a Ref
#     metadata entry in the tag.  This is used to select only tags from
#     Policy, or devref, or so forth.
#
# files:
#     Info about a specific file.  Key is the the filename, value another
#     hash with the following keys:
#      - pkg: package name
#      - version: package version
#      - arch: package architecture
#      - type: one of 'binary', 'udeb' or 'source'
#      - overrides: hash with all overrides for this file as keys
#
# only_issue:
#     A hash of tags to issue.  If this hash is not empty, only tags noted
#     in that has will be issued regardless of which tags are seen.
#
# show_experimental:
#     True if experimental tags should be displayed.  False by default.
#
# show_overrides:
#     True if overridden tags should be displayed.  False by default.
#
# show_pedantic:
#     True if pedantic tags should be displayed.  False by default.
#
# statistics:
#     Statistics per file.  Key is the filename, value another hash with
#     the following keys:
#      - tags: hash of tag names to count of times seen
#      - severity: hash of severities to count of times seen
#      - certainty: hash of certainties to count of times seen
#      - types: hash of tag code (E/W/I/P) to count of times seen
#      - overrides: hash whose keys and values are the same as the above
#     The overrides hash holds the tag data for tags that were overridden.
#     Data for overridden tags is not added to the regular hashes.
#
# suppress:
#     A hash of tags that should be suppressed.  Suppressed tags are not
#     printed and do not add to any of the statistics.  They're treated as
#     if they don't exist.
sub new {
    my ($class) = @_;
    my $self = {
        current           => undef,
        display_level     => {
            wishlist  => { 'wild-guess' => 0, possible => 0, certain => 0 },
            minor     => { 'wild-guess' => 0, possible => 0, certain => 1 },
            normal    => { 'wild-guess' => 0, possible => 1, certain => 1 },
            important => { 'wild-guess' => 1, possible => 1, certain => 1 },
            serious   => { 'wild-guess' => 1, possible => 1, certain => 1 },
        },
        display_source    => {},
        files             => {},
        only_issue        => {},
        show_experimental => 0,
        show_overrides    => 0,
        show_pedantic     => 0,
        statistics        => {},
        suppress          => {},
    };
    bless($self, $class);
    $GLOBAL = $self unless $GLOBAL;
    return $self;
}

=item tag(TAG, [EXTRA, ...])

Issue the Lintian tag TAG, possibly suppressing it or not displaying it
based on configuration.  EXTRA, if present, is additional information to
display with the tag.  It can be given as a list of strings, in which case
they're joined by a single space before display.

This method can be called either as a class method (which is exported by
the Lintian::Tags module) or as an instance method.  If called as a class
method, it uses the first-constructed Lintian::Tags object as its
underlying object.

This method throws an exception if it is called without file_start() being
called first or if an attempt is made to issue an unknown tag.

=cut

#'# for cperl-mode

# Check if a given tag with associated extra information is overridden by the
# overrides for the current file.  This may require checking for matches
# against override data with wildcards.  Returns undef if the tag is not
# overridden or the override if the tag is.
sub _check_overrides {
    my ($self, $tag, $extra) = @_;
    my $overrides = $self->{info}{$self->{current}}{overrides}{$tag};
    return unless $overrides;
    if (exists $overrides->{''}) {
        $overrides->{''}++;
        return $tag;
    } elsif ($extra ne '' and exists $overrides->{$extra}) {
        $overrides->{$extra}++;
        return "$tag $extra";
    } elsif ($extra ne '') {
        for (sort keys %$overrides) {
            my $pattern = $_;
            next unless ($pattern =~ /^\*/ or $pattern =~ /\*\z/);
            my ($start, $end) = ('', '');
            $start = '.*' if $pattern =~ s/^\*//;
            $end   = '.*' if $pattern =~ s/\*$//;
            if ($extra =~ /^$start\Q$pattern\E$end\z/) {
                $overrides->{$_}++;
                return "$tag $_";
            }
        }
    }
    return;
}

# Record tag statistics.  Takes the tag, the Lintian::Tag::Info object and a
# flag saying whether the tag was overridden.
sub _record_stats {
    my ($self, $tag, $info, $overridden) = @_;
    my $stats = $self->{statistics}{$self->{current}};
    if ($overridden) {
        $stats = $self->{statistics}{$self->{current}}{overrides};
    }
    $stats->{tags}{$tag}++;
    $stats->{severity}{$info->severity}++;
    $stats->{certainty}{$info->certainty}++;
    $stats->{types}{$info->code}++;
}

sub tag {
    unless (ref $_[0] eq 'Lintian::Tags') {
        unshift(@_, $GLOBAL);
    }
    my ($self, $tag, @extra) = @_;
    unless ($self->{current}) {
        die "tried to issue tag $tag without starting a file";
    }
    return if $self->suppressed($tag);

    # Clean up @extra and collapse it to a string.  Lintian code
    # doesn't treat the distinction between extra arguments to tag() as
    # significant, so we may as well take care of this up front.
    @extra = grep { defined($_) and $_ ne '' } map { s/\n/\\n/g; $_ } @extra;
    my $extra = join(' ', @extra);
    $extra = '' unless defined $extra;

    # Retrieve the tag metadata and display the tag if the configuration
    # says to display it.
    my $info = Lintian::Tag::Info->new($tag);
    unless ($info) {
        die "tried to issue unknown tag $tag";
    }
    my $overridden = $self->_check_overrides($tag, $extra);
    $self->_record_stats($tag, $info, $overridden);
    return if (defined($overridden) and not $self->{show_overrides});
    return unless $self->displayed($tag);
    my $file = $self->{info}{$self->{current}};
    $Lintian::Output::GLOBAL->print_tag($file, $info, $extra, $overridden);
}

=back

=head1 INSTANCE METHODS

=head2 Configuration

=over 4

=item display(OPERATION, RELATION, SEVERITY, CERTAINTY)

Configure which tags are displayed by severity and certainty.  OPERATION
is C<+> to display the indicated tags, C<-> to not display the indicated
tags, or C<=> to not display any tags except the indicated ones.  RELATION
is one of C<< < >>, C<< <= >>, C<=>, C<< >= >>, or C<< > >>.  The
OPERATION will be applied to all pairs of severity and certainty that
match the given RELATION on the SEVERITY and CERTAINTY arguments.  If
either of those arguments are undefined, the action applies to any value
for that variable.  For example:

    $tags->display('=', '>=', 'important');

turns off display of all tags and then enables display of any tag (with
any certainty) of severity important or higher.

    $tags->display('+', '>', 'normal', 'possible');

adds to the current configuration display of all tags with a severity
higher than normal and a certainty higher than possible (so
important/certain and serious/certain).

    $tags->display('-', '=', 'minor', 'possible');

turns off display of tags of severity minor and certainty possible.

This method throws an exception on errors, such as an unknown severity or
certainty or an impossible constraint (like C<< > serious >>).

=cut

# Generate a subset of a list given the element and the relation.  This
# function makes a hard assumption that $rel will be one of <, <=, =, >=,
# or >.  It is not syntax-checked.
sub _relation_subset {
    my ($self, $element, $rel, @list) = @_;
    if ($rel eq '=') {
        return grep { $_ eq $element } @list;
    }
    if (substr($rel, 0, 1) eq '<') {
        @list = reverse @list;
    }
    my $found;
    for my $i (0..$#list) {
        if ($element eq $list[$i]) {
            $found = $i;
            last;
        }
    }
    return unless defined($found);
    if (length($rel) > 1) {
        return @list[$found .. $#list];
    } else {
        return if $found == $#list;
        return @list[($found + 1) .. $#list];
    }
}

# Given the operation, relation, severity, and certainty, produce a
# human-readable representation of the display level string for errors.
sub _format_level {
    my ($self, $op, $rel, $severity, $certainty) = @_;
    if (not defined $severity and not defined $certainty) {
        return "$op $rel";
    } elsif (not defined $severity) {
        return "$op $rel $certainty (certainty)";
    } elsif (not defined $certainty) {
        return "$op $rel $severity (severity)";
    } else {
        return "$op $rel $severity/$certainty";
    }
}

sub display {
    my ($self, $op, $rel, $severity, $certainty) = @_;
    unless ($op =~ /^[+=-]\z/ and $rel =~ /^(?:[<>]=?|=)\z/) {
        my $error = $self->_format_level($op, $rel, $severity, $certainty);
        die "invalid display constraint " . $error;
    }
    if ($op eq '=') {
        for my $s (@SEVERITIES) {
            for my $c (@CERTAINTIES) {
                $self->{display_level}{$s}{$c} = 0;
            }
        }
    }
    my $status = ($op eq '-' ? 0 : 1);
    my (@severities, @certainties);
    if ($severity) {
        @severities = $self->_relation_subset($severity, $rel, @SEVERITIES);
    } else {
        @severities = @SEVERITIES;
    }
    if ($certainty) {
        @certainties = $self->_relation_subset($certainty, $rel, @CERTAINTIES);
    } else {
        @certainties = @CERTAINTIES;
    }
    unless (@severities and @certainties) {
        my $error = $self->_format_level($op, $rel, $severity, $certainty);
        die "invalid display constraint " . $error;
    }
    for my $s (@severities) {
        for my $c (@certainties) {
            $self->{display_level}{$s}{$c} = $status;
        }
    }
}

=item only([TAG [, ...]])

Limits the displayed tags to only the listed tags.  One or more tags may
be given.  If no tags are given, resets the Lintian::Tags object to
display all tags (subject to other constraints).

=cut

sub only {
    my ($self, @tags) = @_;
    $self->{only_issue} = {};
    for my $tag (@tags) {
        $self->{only_issue}{$tag} = 1;
    }
}

=item show_experimental(BOOL)

If BOOL is true, configure experimental tags to be shown.  If BOOL is
false, configure experimental tags to not be shown.

=cut

sub show_experimental {
    my ($self, $bool) = @_;
    $self->{show_experimental} = $bool ? 1 : 0;
}

=item show_overrides(BOOL)

If BOOL is true, configure overridden tags to be shown.  If BOOL is false,
configure overridden tags to not be shown.

=cut

sub show_overrides {
    my ($self, $bool) = @_;
    $self->{show_overrides} = $bool ? 1 : 0;
}

=item show_pedantic(BOOL)

If BOOL is true, configure pedantic tags to be shown.  If BOOL is false,
configure pedantic tags to not be shown.

=cut

sub show_pedantic {
    my ($self, $bool) = @_;
    $self->{show_pedantic} = $bool ? 1 : 0;
}

=item sources([SOURCE [, ...]])

Limits the displayed tags to only those from the listed sources.  One or
more sources may be given.  If no sources are given, resets the
Lintian::Tags object to display tags from any source.  Tag sources are the
names of references from the Ref metadata for the tags.

=cut

sub sources {
    my ($self, @sources) = @_;
    $self->{display_source} = {};
    for my $source (@sources) {
        $self->{display_source}{$source} = 1;
    }
}

=item suppress(TAG [, ...])

Suppress the specified tags.  These tags will not be shown and will not
contribute to statistics.  This method may be called more than once,
adding additional tags to suppress.  There is no way to unsuppress a tag
after it has been suppressed.

=cut

sub suppress {
    my ($self, @tags) = @_;
    for my $tag (@tags) {
        $self->{suppress}{$tag} = 1;
    }
}

=back

=head2 File Metadata

=over 4

=item file_start(FILE, PACKAGE, VERSION, ARCH, TYPE)

Adds a new file with the given metadata, initializes the data structures
used for statistics and overrides, and makes it the default file for which
tags will be issued.  Also call Lintian::Output::print_end_pkg() to end
the previous file, if any, and Lintian::Output::print_start_pkg() to start
the new file.

This method throws an exception if the file being added was already added
earlier.

=cut

sub file_start {
    my ($self, $file, $pkg, $version, $arch, $type) = @_;
    if (exists $self->{info}{$file}) {
        die "duplicate of file $file added to Lintian::Tags object";
    }
    $self->{info}{$file} = {
        file      => $file,
        package   => $pkg,
        version   => $version,
        arch      => $arch,
        type      => $type,
        overrides => {},
    };
    $self->{statistics}{$file} = {
        types     => {},
        severity  => {},
        certainty => {},
        tags      => {},
        overrides => {},
    };
    if ($self->{current}) {
        my $info = $self->{info}{$self->{current}};
        $Lintian::Output::GLOBAL->print_end_pkg($info);
    }
    $self->{current} = $file;
    if ($file !~ /\.changes$/) {
        $Lintian::Output::GLOBAL->print_start_pkg($self->{info}{$file});
    }
}

=item file_overrides(OVERRIDE-FILE)

Read OVERRIDE-FILE and add the overrides found there which match the
metadata of the current file (package and type).  The overrides are added
to the overrides hash in the info hash entry for the current file.

file_start() must be called before this method.  This method throws an
exception if there is no current file and calls fail() if the override
file cannot be opened.

=cut

sub file_overrides {
    my ($self, $overrides) = @_;
    unless (defined $self->{current}) {
        die "no current file when adding overrides";
    }
    my $info = $self->{info}{$self->{current}};
    open(my $file, '<', $overrides)
        or fail("cannot open override file $overrides: $!");
    local $_;
    while (<$file>) {
        s/^\s+//;
        s/\s+$//;
        next if /^(?:\#|\z)/;
        s/\s+/ /go;
        my $override = $_;
        $override =~ s/^\Q$info->{package}\E( \Q$info->{type}\E)?: //;
        if ($override eq '' or $override !~ /^[\w.+-]+(\s.*)?$/) {
            tag('malformed-override', $_);
        } else {
            my ($tag, $extra) = split(/ /, $override, 2);
            $extra = '' unless defined $extra;
            $info->{overrides}{$tag}{$extra} = 0;
        }
    }
    close $file;
}

=item file_end()

Ends processing of a file.  The main reason for this call is to, in turn,
call Lintian::Output::print_end_pkg() to mark the end of the package.

=cut

sub file_end {
    my ($self) = @_;
    if ($self->{current}) {
        my $info = $self->{info}{$self->{current}};
        $Lintian::Output::GLOBAL->print_end_pkg($info);
    }
    undef $self->{current};
}

=back

=head2 Statistics

=over 4

=item overrides(FILE)

Returns a reference to the overrides hash for the given file.  The keys of
this hash are the tags for which are overrides.  The value for each key is
another hash, whose keys are the extra data matched by that override and
whose values are the counts of tags that matched that override.  Overrides
matching any tag by that name are stored with the empty string as
metadata, so:

    my $overrides = $tags->overrides('/some/file');
    print "$overrides->{'some-tag'}{''}\n";

will print out the number of tags that matched a general override for the
tag some-tag, regardless of what extra data was associated with it.

=cut

sub overrides {
    my ($self, $file) = @_;
    if ($self->{info}{$file}) {
        return $self->{info}{$file}{overrides};
    } else {
        return;
    }
}

=item statistics([FILE])

Returns a reference to the statistics hash for the given file or, if FILE
is omitted, a reference to the full statistics hash for all files.  In the
latter case, the returned hash reference has as keys the file names and as
values the per-file statistics.

The per-file statistics has a set of hashes of keys to times seen in tags:
tag names (the C<tags> key), severities (the C<severity> key), certainties
(the C<certainty> key), and tag codes (the C<types> key).  It also has a
C<overrides> key which has as its value another hash with those same four
keys, which keeps statistics on overridden tags (not included in the
regular counts).

=cut

sub statistics {
    my ($self, $file) = @_;
    return $self->{statistics}{$file} if $file;
    return $self->{statistics};
}

=back

=head2 Tag Reporting

=over 4

=item displayed(TAG)

Returns true if the given tag would be displayed given the current
configuration, false otherwise.  This does not check overrides, only whether
the tag severity, certainty, and source warrants display given the
configuration.

=cut

sub displayed {
    my ($self, $tag) = @_;
    my $info = Lintian::Tag::Info->new($tag);
    return 0 if ($info->experimental and not $self->{show_experimental});
    my $severity = $info->severity;
    my $certainty = $info->certainty;

    # Pedantic is determined separately by the show_pedantic setting rather
    # than by the normal display levels.  This is probably a mistake; this
    # should probably be consistent.
    #
    # Severity and certainty should always be available, but avoid Perl
    # warnings if the tag data is corrupt for some reason.
    my $display;
    if ($severity eq 'pedantic') {
        $display = $self->{show_pedantic} ? 1 : 0;
    } elsif ($severity and $certainty) {
        $display = $self->{display_level}{$severity}{$certainty};
    } else {
        $display = 1;
    }

    # If display_source is set, we need to check whether any of the references
    # of this tag occur in display_source.
    if (keys %{ $self->{display_source} }) {
        my @sources = $info->sources;
        unless (grep { $self->{display_source}{$_} } @sources) {
            $display = 0;
        }
    }
    return $display;
}

=item suppressed(TAG)

Returns true if the given tag would be suppressed given the current
configuration, false otherwise.  This is different than displayed() in
that a tag is only suppressed if Lintian treats the tag as if it's never
been seen, doesn't update statistics, and doesn't change its exit status.
Tags are suppressed via only() or suppress().

=cut

#'# for cperl-mode

sub suppressed {
    my ($self, $tag) = @_;
    if (keys %{ $self->{only_issue} }) {
        return 1 unless $self->{only_issue}{$tag};
    }
    return 1 if $self->{suppress}{$tag};
    return;
}

=back

=head1 AUTHOR

Originally written by Russ Allbery <rra@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1), Lintian::Output(3), Lintian::Tag::Info(3)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl ts=4 sw=4 et

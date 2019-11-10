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
use autodie;

use Carp qw(croak);
use Exporter qw(import);
use List::MoreUtils qw(any);
use Path::Tiny;

use Lintian::Output;

BEGIN {
    our @EXPORT_OK = qw(tag);
}

# The default Lintian::Tags object, set to the first one constructed and
# used by default if tag() is called without a reference to a particular
# object.
our $GLOBAL;

# Ordered lists of severities and certainties, used for display level parsing.
our @SEVERITIES
  = qw(classification pedantic wishlist minor normal important serious);
our @CERTAINTIES = qw(wild-guess possible certain);

=head1 NAME

Lintian::Tags - Manipulate and output Lintian tags

=head1 SYNOPSIS

    my $tags = Lintian::Tags->new;
    my $proc = Lintian::Processable->new;
    $proc->init_from_file('/path/to/file');
    $tags->file_start ($proc);
    $tags->file_overrides ('/path/to/an/overrides-file');
    $tags->tag ('lintian-tag', 'extra tag information');
    tag ('other-lintian-tag', 'with some extra data');
    tag ('third-lintian-tag'); # with no extra).
    my %overrides = $tags->overrides ($proc);
    my %stats = $tags->statistics;
    if ($tags->displayed ('lintian-tag')) {
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
#     Info about a specific file.  Key is the filename, value another
#     hash with the following keys:
#      - pkg: package name
#      - version: package version
#      - arch: package architecture
#      - type: one of 'binary', 'udeb' or 'source'
#      - overrides: hash with all overrides for this file as keys
#
# profile:
#     The Lintian::Profile (if any).  If not undef, this is used to
#     determine known tags, severity of tags (indirectly) and whether
#     or not a given tag is overridable.  It also partly affects
#     which tags are suppressed (see the suppressed method below).
#
# show_experimental:
#     True if experimental tags should be displayed.  False by default.
#
# show_overrides:
#     True if overridden tags should be displayed.  False by default.
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
sub new {
    my ($class) = @_;
    my $self = {
        current           => undef,
        display_level     => {
            classification =>
              { 'wild-guess' => 0, possible => 0, certain => 0 },
            wishlist  => { 'wild-guess' => 0, possible => 0, certain => 0 },
            minor     => { 'wild-guess' => 0, possible => 0, certain => 1 },
            normal    => { 'wild-guess' => 0, possible => 1, certain => 1 },
            important => { 'wild-guess' => 1, possible => 1, certain => 1 },
            serious   => { 'wild-guess' => 1, possible => 1, certain => 1 },
        },
        display_source       => {},
        files                => {},
        unused_overrides     => 0,
        ignored_overrides    => {},
        profile              => undef,
        show_experimental    => 0,
        show_overrides       => 0,
        statistics           => {},
        queue                => [],
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

sub tag {
    unless (ref $_[0] eq 'Lintian::Tags') {
        unshift(@_, $GLOBAL);
    }
    my ($self, $tag, @extra) = @_;
    unless ($self->{current}) {
        die "tried to issue tag $tag without starting a file";
    }

    push(@{$self->{queue}}, [$tag, @extra]);

    return;
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
        die 'invalid display constraint ' . $error;
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
        die 'invalid display constraint ' . $error;
    }
    for my $s (@severities) {
        for my $c (@certainties) {
            $self->{display_level}{$s}{$c} = $status;
        }
    }
    return;
}

=item show_experimental(BOOL)

If BOOL is true, configure experimental tags to be shown.  If BOOL is
false, configure experimental tags to not be shown.

=cut

sub show_experimental {
    my ($self, $bool) = @_;
    $self->{show_experimental} = $bool ? 1 : 0;
    return;
}

=item show_overrides(BOOL)

If BOOL is true, configure overridden tags to be shown.  If BOOL is false,
configure overridden tags to not be shown.

=cut

sub show_overrides {
    my ($self, $bool) = @_;
    $self->{show_overrides} = $bool ? 1 : 0;
    return;
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
    return;
}

=item profile(PROFILE)

Use the PROFILE (Lintian::Profile) to determine which tags are
suppressed, the severity of the tags and which tags are
non-overridable.

=cut

sub profile {
    my ($self, $profile) = @_;
    $self->{profile} = $profile;
    return;
}

=back

=head2 File Metadata

=over 4

=back

=head2 Statistics

=over 4

=item overrides(PROC)

Returns a reference to the overrides hash for the given processable.  The keys of
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
    my ($self, $proc) = @_;
    if ($proc and $self->{info}{$proc->pkg_path}) {
        return $self->{info}{$proc->pkg_path}{overrides};
    }
    return;
}

=item statistics([PROC])

Returns a reference to the statistics hash for the given processable or, if PROC
is omitted, a reference to the full statistics hash for all files.  In the
latter case, the returned hash reference has as keys the file names and as
values the per-file statistics.

The per-file statistics has a set of hashes of keys to times seen in tags:
tag names (the C<tags> key), severities (the C<severity> key), certainties
(the C<certainty> key), and tag codes (the C<types> key).  It also has an
C<overrides> key which has as its value another hash with those same four
keys, which keeps statistics on overridden tags (not included in the
regular counts).

=cut

sub statistics {
    my ($self, $proc) = @_;
    return $self->{statistics}{$proc->pkg_path} if $proc;
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
    # Note, we get the known as it will be suppressed by
    # $self->suppressed below if the tag is not enabled.
    my $info = $self->{profile}->get_tag($tag, 1);
    return 0 if ($info->experimental and not $self->{show_experimental});
    return 0 if $self->suppressed($tag);
    my $severity = $info->severity;
    my $certainty = $info->certainty;

    my $display = $self->{display_level}{$severity}{$certainty};

    # If display_source is set, we need to check whether any of the references
    # of this tag occur in display_source.
    if (keys %{ $self->{display_source} }) {
        my @sources = $info->sources;
        unless (any { $self->{display_source}{$_} } @sources) {
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
Tags are suppressed via profile().

=cut

#'# for cperl-mode

sub suppressed {
    my ($self, $tag) = @_;
    return 1 if $self->{profile} and not $self->{profile}->get_tag($tag);
    return;
}

=item ignored_overrides()

Returns a hash of tags, for which overrides have been ignored.  The
keys are tag names and the value is the number of overrides that has
been ignored.

=cut

sub ignored_overrides {
    my ($self) = @_;
    return $self->{ignored_overrides};
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
# vim: syntax=perl sw=4 sts=4 sr et

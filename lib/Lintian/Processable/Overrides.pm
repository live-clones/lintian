# -*- perl -*- Lintian::Processable::Overrides -- access to override data
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

package Lintian::Processable::Overrides;

use strict;
use warnings;
use autodie;

use Path::Tiny;

use Lintian::Architecture qw(:all);
use Lintian::Util qw($PKGNAME_REGEX strip gunzip_file is_ancestor_of);

use constant EMPTY => q{};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::Overrides - access to override data

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Processable::Overrides provides an interface to package data for overrides.

=head1 INSTANCE METHODS

=over 4

=item add_overrides

=cut

sub add_overrides {
    my ($self) = @_;

    my $unpackedpath = path($self->groupdir)->child('unpacked')->stringify;
    die "No unpacked data in $unpackedpath"
      unless -d $unpackedpath;

    my $overridepath = path($self->groupdir)->child('override')->stringify;
    unlink($overridepath)
      if -e $overridepath;

    # pick the first
    my @candidates;
    if ($self->type eq 'source') {
        # prefer source/lintian-overrides to source.lintian-overrides
        @candidates = ('debian/source/lintian-overrides',
            'debian/source.lintian-overrides');
    } else {
        @candidates = ('usr/share/lintian/overrides/' . $self->name);
    }

    my $packageoverridepath;
    for my $relative (@candidates) {

        my $candidate = "$unpackedpath/$relative";
        if (-f $candidate) {
            $packageoverridepath = $candidate;

        } elsif (-f "$candidate.gz") {
            $packageoverridepath = "$candidate.gz";
        }

        last
          if $packageoverridepath;
    }

    return
      unless length $packageoverridepath;

    return
      unless is_ancestor_of($unpackedpath, $packageoverridepath);

    if ($packageoverridepath =~ /\.gz$/) {
        gunzip_file($packageoverridepath, $overridepath);
    } else {
        link($packageoverridepath, $overridepath);
    }

    return;
}

=item overrides(OVERRIDE-FILE)

Read OVERRIDE-FILE and add the overrides found there which match the
metadata of the current file (package and type).  The overrides are added
to the overrides hash in the info hash entry for the current file.

file_start() must be called before this method.  This method throws an
exception if there is no current file and calls fail() if the override
file cannot be opened.

=cut

sub overrides {
    my ($self) = @_;

    my $package = $self->name;
    my $architecture = $self->architecture;
    my $type = $self->type;

    my @comments;
    my %previous;

    my $path = path($self->groupdir)->child('override')->stringify;

    return
      unless -f $path;

    my %override_data;

    open(my $fh, '<:encoding(UTF-8)', $path);

  OVERRIDE:
    while (my $line = <$fh>) {

        my $processed = $line;
        strip $processed;

        if ($processed eq EMPTY) {
            # Throw away comments, as they are not attached to a tag
            # also throw away the option of "carrying over" the last
            # comment
            @comments = ();
            %previous = ();
            next;
        }

        if ($processed =~ /^#/) {
            $processed =~ s/^# ?//;
            push(@comments, $processed);
            next;
        }

        $processed =~ s/\s+/ /g;

        # The override looks like the following:
        # [[pkg-name] [arch-list] [pkg-type]:] <tag> [extra]
        # - Note we do a strict package name check here because
        #   parsing overrides is a bit ambiguous (see #699628)
        if (
            $processed =~ m/\A (?:                   # start optional part
                  (?:\Q$package\E)?                 # optionally starts with package name -> $1
                  (?: \s*+ \[([^\]]+?)\])?          # optionally followed by an [arch-list] (like in B-D) -> $2
                  (?:\s*+ ([a-z]+) \s*+ )?          # optionally followed by the type -> $3
                :\s++)?                             # end optional part
                ([\-\+\.a-zA-Z_0-9]+ (?:\s.+)?)     # <tag-name> [extra] -> $4
                   \Z/xsm
        ) {
            # Valid - so far at least
            my ($archlist, $opkg_type, $tagdata)= ($1, $2, $3, $4);

            my ($tagname, $extra) = split(/ /, $tagdata, 2);

            if ($opkg_type and $opkg_type ne $type) {
                $self->tag('malformed-override',
"Override of $tagname for package type $opkg_type (expecting $type) at line $."
                );
                next;
            }

            if ($architecture eq 'all' && $archlist) {
                $self->tag('malformed-override',
"Architecture list for arch:all package at line $. (for tag $tagname)"
                );
                next;
            }

            if ($archlist) {
                # parse and figure
                my (@archs) = split(m/\s++/o, $archlist);
                my $negated = 0;
                my $found = 0;

                foreach my $a (@archs){
                    $negated++ if $a =~ s/^!//o;
                    if (is_arch_wildcard($a)) {
                        $found = 1
                          if wildcard_includes_arch($a, $architecture);
                    } elsif (is_arch($a)) {
                        $found = 1 if $a eq $architecture;
                    } else {
                        $self->tag('malformed-override',
"Unknown architecture \"$a\" at line $. (for tag $tagname)"
                        );
                        next OVERRIDE;
                    }
                }

                if ($negated > 0 && scalar @archs != $negated){
                    # missing a ! somewhere
                    $self->tag('malformed-override',
"Inconsistent architecture negation at line $. (for tag $tagname)"
                    );
                    next;
                }

                # missing wildcard checks and sanity checking archs $arch
                if ($negated) {
                    $found = $found ? 0 : 1;
                }

                next
                  unless $found;
            }

            if (($previous{tag} // EMPTY) eq $tagname
                && !scalar @comments){
                # There are no new comments, no "empty line" in between and
                # this tag is the same as the last, so we "carry over" the
                # comment from the previous override (if any).
                #
                # Since L::T::Override is (supposed to be) immutable, the new
                # override can share the reference with the previous one.
                push(@comments, @{$previous{comments}});
            }

            my %current;
            $current{tag} = $tagname;

            # record line number
            $current{line} = $.;

            # does not seem to be used anywhere
            $current{arch} = 'any';

            $extra //= EMPTY;
            $current{extra} = $extra;

            if ($extra =~ m/\*/o) {
                # It is a pattern, pre-compute it
                my $pattern = $extra;
                my $end = ''; # Trailing "match anything" (if any)
                my $pat = ''; # The rest of the pattern
                 # Split does not help us if $pattern ends with *
                 # so we deal with that now
                if ($pattern =~ s/\Q*\E+\z//o){
                    $end = '.*';
                }

                # Are there any * left (after the above)?
                if ($pattern =~ m/\Q*\E/o) {
                    # this works even if $text starts with a *, since
                    # that is split as '', <text>
                    my @pargs = split(m/\Q*\E++/o, $pattern);
                    $pat = join('.*', map { quotemeta($_) } @pargs);
                } else {
                    $pat = $pattern;
                }

                $current{pattern} = qr/$pat$end/;
            }

            $current{comments} = [];
            push(@{$current{comments}}, @comments);
            @comments = ();

            $override_data{$tagname} //= {};
            $override_data{$tagname}{$extra} = \%current;

            %previous = %current;

        } else {
            # We know this to be a bad override; check if it might be
            # an override for a different package.
            unless ($processed =~ m/^\Q$package\E[\s:\[]/) {
                # So, we got an override that does not start with the
                # package name - cases include:
                #  1 <tag> ...
                #  2 <tag> something: ...
                #  3 <wrong-pkg> [archlist] <type>: <tag> ...
                #  4 <wrong-pkg>: <tag> ...
                #  5 <wrong-pkg> <type>: <tag> ...
                #
                # Case 2 and 5 are hard to distinguish from one another.

                # First, remove the archlist if present (simplifies
                # the next step)
                $processed =~ s/([^:\[]+)?\[[^\]]+\]([^:]*):/$1 $2:/;
                $processed =~ s/\s\s++/ /g;

                if ($processed
                    =~ m/^($PKGNAME_REGEX)?(?: (?:binary|changes|source|udeb))? ?:/o
                ) {
                    my $opkg = $1;
                    # Looks like a wrong package name - technically,
                    # $opkg could be a tag if the tag information is
                    # present, but it is very unlikely.
                    $self->tag('malformed-override',
"Possibly wrong package in override at line $. (got $opkg, expected $package)"
                    );
                    next;
                }
            }
            # Nope, package name appears to match (or not present
            # at all), not sure what the problem is so we just throw a
            # generic parse error.

            $self->tag('malformed-override', "Cannot parse line $.: $line");
        }
    }

    close($fh);

    return \%override_data;
}

1;

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1)

=cut

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

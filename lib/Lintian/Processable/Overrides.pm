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

use v5.20;
use warnings;
use utf8;
use autodie;

use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use List::MoreUtils qw(none);
use Path::Tiny;

use Lintian::Architecture qw(:all);
use Lintian::Util qw(is_ancestor_of);

use constant EMPTY => q{};
use constant SPACE => q{ };

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

    my $unpackedpath = path($self->basedir)->child('unpacked')->stringify;
    die "No unpacked data in $unpackedpath"
      unless -d $unpackedpath;

    my $overridepath = path($self->basedir)->child('override')->stringify;
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
        gunzip($packageoverridepath => $overridepath)
          or die "gunzip $packageoverridepath failed: $GunzipError";

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

    my @comments;
    my %previous;

    my $path = path($self->basedir)->child('override')->stringify;

    return
      unless -f $path;

    my %override_data;

    open(my $fh, '<:encoding(UTF-8)', $path);

    while (my $line = <$fh>) {

        my $remaining = $line;

        # trim both ends
        $remaining =~ s/^\s+|\s+$//g;

        if ($remaining eq EMPTY) {
            # Throw away comments, as they are not attached to a tag
            # also throw away the option of "carrying over" the last
            # comment
            @comments = ();
            %previous = ();
            next;
        }

        if ($remaining =~ /^#/) {
            $remaining =~ s/^# ?//;
            push(@comments, $remaining);
            next;
        }

        # reduce white space
        $remaining =~ s/\s+/ /g;

        # [[pkg-name] [arch-list] [pkg-type]:] <tag> [context]
        my $require_colon = 0;
        my @architectures;

        # strip package name, if present; require name
        # parsing overrides is ambiguous (see #699628)
        my $package = $self->name;
        if ($remaining =~ s/^\Q$package\E\b\s*//) {
            $require_colon = 1;
        }

        # remove architecture list
        if ($remaining =~ s/^\[([^\]]*)\]\s*//) {
            @architectures = split(SPACE, $1);
            $require_colon = 1;
        }

        # remove package type
        my $type = $self->type;
        if ($remaining =~ s/^\Q$type\E\b\s*//) {
            $require_colon = 1;
        }

        # require and remove colon when any package details are present
        if ($require_colon && $remaining !~ s/^\s*:\s*//) {
            $self->tag('malformed-override',"Expected a colon in line $.");
            next;
        }

        my $hint = $remaining;

        if (@architectures && $self->architecture eq 'all') {
            $self->tag('malformed-override',
                "Architecture list for arch:all package in line $.");
            next;
        }

        # check for missing negations
        my $negations = scalar grep { /^!/ } @architectures;
        unless ($negations == @architectures || $negations == 0) {
            $self->tag('malformed-override',
                "Inconsistent architecture negation in line $.");
            next;
        }

        my @invalid = grep { !valid_wildcard($_) } @architectures;
        $self->tag('malformed-override',
            "Unknown architecture wildcard $_ in line $.")
          for @invalid;

        next
          if @invalid;

        # proceed when none specified
        next
          if @architectures
          && none { wildcard_matches($_, $self->architecture) }
        @architectures;

        my ($tagname, $context) = split(SPACE, $hint, 2);

        $self->tag('malformed-override', "Cannot parse line $.: $line")
          unless length $tagname;

        $context //= EMPTY;

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

        $current{context} = $context;

        if ($context =~ m/\*/) {
            # It is a pattern, pre-compute it
            my $pattern = $context;
            my $end = ''; # Trailing "match anything" (if any)
            my $pat = ''; # The rest of the pattern
             # Split does not help us if $pattern ends with *
             # so we deal with that now
            if ($pattern =~ s/\Q*\E+\z//){
                $end = '.*';
            }

            # Are there any * left (after the above)?
            if ($pattern =~ m/\Q*\E/) {
                # this works even if $text starts with a *, since
                # that is split as '', <text>
                my @pargs = split(m/\Q*\E++/, $pattern);
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
        $override_data{$tagname}{$context} = \%current;

        %previous = %current;

    }

    close $fh;

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

# maintainer-scripts/diversion -- lintian check script -*- perl -*-
#
# Copyright © 1998 Richard Braakman
# Copyright © 2002 Josip Rodin
# Copyright © 2016-2019 Chris Lamb <lamby@debian.org>
# Copyright © 2021 Felix Lechner
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, you can find it on the World Wide
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::MaintainerScripts::Diversion;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any none);
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

# When detecting commands inside shell scripts, use this regex to match the
# beginning of the command rather than checking whether the command is at the
# beginning of a line.
const my $LEADING_PATTERN=>
'(?:(?:^|[`&;(|{])\s*|(?:if|then|do|while|!)\s+|env(?:\s+[[:alnum:]_]+=(?:\S+|\"[^"]*\"|\'[^\']*\'))*\s+)';
const my $LEADING_REGEX => qr/$LEADING_PATTERN/;

has added_diversions => (is => 'rw', default => sub { {} });
has removed_diversions => (is => 'rw', default => sub { {} });
has expand_diversions => (is => 'rw', default => 0);

sub visit_control_files {
    my ($self, $item) = @_;

    return
      unless $item->is_maintainer_script;

    return
      unless length $item->interpreter;

    return
      unless $item->is_open_ok;

    open(my $fd, '<', $item->unpacked_path)
      or die encode_utf8('Cannot open ' . $item->unpacked_path);

    my $stashed = $EMPTY;

    my $position = 1;
    while (my $possible_continuation = <$fd>) {

        chomp $possible_continuation;

        # skip empty lines
        next
          if $possible_continuation =~ /^\s*$/;

        # skip comment lines
        next
          if $possible_continuation =~ /^\s*\#/;

        my $no_comment = remove_comments($possible_continuation);

        # Concatenate lines containing continuation character (\)
        # at the end
        if ($no_comment =~ s{\\$}{}) {

            $stashed .= $no_comment;

            next;
        }

        my $line = $stashed . $no_comment;
        $stashed = $EMPTY;

        if (   $line =~ m{$LEADING_REGEX(?:/usr/sbin/)?dpkg-divert\s}
            && $line !~ /--(?:help|list|truename|version)/) {

            $self->hint('package-uses-local-diversion',
                "[control/$item:$position]")
              if $line =~ /--local/;

            my $mode = $line =~ /--remove/ ? 'remove' : 'add';

            my ($divert) = ($line =~ /dpkg-divert\s*(.*)$/);

            $divert =~ s{\s*(?:\$[{]?[\w:=-]+[}]?)*\s*
                                # options without arguments
                              --(?:add|quiet|remove|rename|no-rename|test|local
                                # options with arguments
                                |(?:admindir|divert|package) \s+ \S+)
                              \s*}{}gxsm;

            # Remove unpaired opening or closing parenthesis
            1 while ($divert =~ m/\G.*?\(.+?\)/gc);
            $divert =~ s/\G(.*?)[()]/$1/;
            pos($divert) = undef;

            # Remove unpaired opening or closing braces
            1 while ($divert =~ m/\G.*?{.+?}/gc);
            $divert =~ s/\G(.*?)[{}]/$1/;
            pos($divert) = undef;

            # position after the last pair of quotation marks, if any
            1 while ($divert =~ m/\G.*?(["']).+?\1/gc);

            # Strip anything matching and after '&&', '||', ';', or '>'
            # this is safe only after we are positioned after the last pair
            # of quotation marks
            $divert =~ s/\G.+?\K(?: && | \|\| | ; | \d*> ).*$//x;
            pos($divert) = undef;

            # Remove quotation marks, they affect:
            # * our var to regex trick
            # * stripping the initial slash if the path was quoted
            $divert =~ s/[\"\']//g;

            # remove the leading / because it's not in the index hash
            $divert =~ s{^/}{};

            # trim both ends
            $divert =~ s/^\s+|\s+$//g;

            $divert = quotemeta($divert);

            # For now just replace variables, they will later be normalised
            $self->expand_diversions(1)
              if $divert =~ s/\\\$\w+/.+/g;

            $self->expand_diversions(1)
              if $divert =~ s/\\\$\\[{]\w+.*?\\[}]/.+/g;

            # handle $() the same way:
            $self->expand_diversions(1)
              if $divert =~ s/\\\$\\\(.+?\\\)/.+/g;

            my %diversion;
            $diversion{script} = $item;
            $diversion{position} = $position;

            $self->added_diversions->{$divert} = \%diversion
              if $mode eq 'add';

            push(@{$self->removed_diversions->{$divert}}, \%diversion)
              if $mode eq 'remove';

            die encode_utf8("mode has unknown value: $mode")
              if none { $mode eq $_ } qw{add remove};
        }

    } continue {
        ++$position;
    }

    return;
}

sub installable {
    my ($self) = @_;

    # If any of the maintainer scripts used a variable in the file or
    # diversion name normalise them all
    if ($self->expand_diversions) {

        for my $divert (keys %{$self->removed_diversions},
            keys %{$self->added_diversions}) {

            # if a wider regex was found, the entries might no longer be there
            next
              unless exists $self->removed_diversions->{$divert}
              || exists $self->added_diversions->{$divert};

            my $widerrx = $divert;
            my $wider = $widerrx;
            $wider =~ s/\\//g;

            # find the widest regex:
            my @matches = grep {
                my $lrx = $_;
                my $l = $lrx;
                $l =~ s/\\//g;

                if ($wider =~ m/^$lrx$/) {
                    $widerrx = $lrx;
                    $wider = $l;
                    1;
                } elsif ($l =~ m/^$widerrx$/) {
                    1;
                } else {
                    0;
                }
            } (
                keys %{$self->removed_diversions},
                keys %{$self->added_diversions});

            # replace all the occurrences with the widest regex:
            for my $k (@matches) {

                next
                  if $k eq $widerrx;

                if (exists $self->removed_diversions->{$k}) {

                    $self->removed_diversions->{$widerrx}
                      = $self->removed_diversions->{$k};

                    delete $self->removed_diversions->{$k};
                }

                if (exists $self->added_diversions->{$k}) {

                    $self->added_diversions->{$widerrx}
                      = $self->added_diversions->{$k};

                    delete $self->added_diversions->{$k};
                }
            }
        }
    }

    for my $divert (keys %{$self->removed_diversions}) {

        if (exists $self->added_diversions->{$divert}) {
            # just mark the entry, because a --remove might
            # happen in two branches in the script, i.e. we
            # see it twice, which is not a bug
            $self->added_diversions->{$divert}{removed} = 1;

        } else {

            for my $item (@{$self->removed_diversions->{$divert}}) {

                my $script = $item->{script};
                my $position = $item->{position};

                next
                  unless $script eq 'postrm';

                # Allow preinst and postinst to remove diversions the
                # package doesn't add to clean up after previous
                # versions of the package.

                my $unquoted = unquote($divert, $self->expand_diversions);
                my $pointer = "[control/$script:$position]";

                $self->hint('remove-of-unknown-diversion', $unquoted,$pointer);
            }
        }
    }

    for my $divert (keys %{$self->added_diversions}) {

        my $script = $self->added_diversions->{$divert}{script};
        my $position = $self->added_diversions->{$divert}{position};

        my $pointer = "[control/$script:$position]";

        my $divertrx = $divert;
        my $unquoted = unquote($divert, $self->expand_diversions);

        $self->hint('orphaned-diversion', $unquoted, $pointer)
          unless exists $self->added_diversions->{$divertrx}{removed};

        # Handle man page diversions somewhat specially.  We may
        # divert away a man page in one section without replacing that
        # same file, since we're installing a man page in a different
        # section.  An example is diverting a man page in section 1
        # and replacing it with one in section 1p (such as
        # libmodule-corelist-perl at the time of this writing).
        #
        # Deal with this by turning all man page diversions into
        # wildcard expressions instead that match everything in the
        # same numeric section so that they'll match the files shipped
        # in the package.
        if ($divertrx =~ m{^(usr\\/share\\/man\\/\S+\\/.*\\\.\d)\w*(\\\.gz\z)})
        {
            $divertrx = "$1.*$2";
            $self->expand_diversions(1);
        }

        if ($self->expand_diversions) {
            $self->hint('diversion-for-unknown-file', $unquoted, $pointer)
              unless (
                any { /$divertrx/ }
                @{$self->processable->installed->sorted_list});

        } else {
            $self->hint('diversion-for-unknown-file', $unquoted, $pointer)
              unless $self->processable->installed->lookup($unquoted);
        }
    }

    return;
}

sub remove_comments {
    my ($line) = @_;

    return $line
      unless length $line;

    my $simplified = $line;

    # Remove quoted strings so we can more easily ignore comments
    # inside them
    $simplified =~ s/(^|[^\\](?:\\\\)*)\'(?:\\.|[^\\\'])+\'/$1''/g;
    $simplified =~ s/(^|[^\\](?:\\\\)*)\"(?:\\.|[^\\\"])+\"/$1""/g;

    # If the remaining string contains what looks like a comment,
    # eat it. In either case, swap the unmodified script line
    # back in for processing (if required) and return it.
    if ($simplified =~ m/(?:^|[^[\\])[\s\&;\(\)](\#.*$)/) {

        my $comment = $1;

        # eat comment
        $line =~ s/\Q$comment\E//;
    }

    return $line;
}

sub unquote {
    my ($string, $replace_regex) = @_;

    $string =~ s{\\}{}g;

    $string =~ s{\.\+}{*}g
      if $replace_regex;

    return $string;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

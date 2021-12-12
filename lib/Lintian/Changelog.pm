# Copyright © 2019 Felix Lechner <felix.lechner@lease-up.com>
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

package Lintian::Changelog;

use v5.20;
use warnings;
use utf8;

use Carp;
use Const::Fast;
use Date::Parse;

use Lintian::Changelog::Entry;

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $ASTERISK => q{*};
const my $UNKNOWN => q{unknown};

use Moo;
use namespace::clean;

=head1 NAME

Lintian::Changelog -- Parse a literal version string into its constituents

=head1 SYNOPSIS

 use Lintian::Changelog;

 my $version = Lintian::Changelog->new;
 $version->set('1.2.3-4', undef);

=head1 DESCRIPTION

A class for parsing literal version strings

=head1 CLASS METHODS

=over 4

=item new ()

Creates a new Lintian::Changelog object.

=cut

=item find_closes

Takes one string as argument and finds "Closes: #123456, #654321" statements
as supported by the Debian Archive software in it. Returns all closed bug
numbers in an array reference.

=cut

sub find_closes {
    my $changes = shift;
    my @closes = ();

    while (
        $changes
        && ($changes
            =~ /(closes:\s*(?:bug)?\#?\s?\d+(?:,\s*(?:bug)?\#?\s?\d+)*)/ig)
    ) {
        push(@closes, $1 =~ /\#?\s?(\d+)/g);
    }

    @closes = sort { $a <=> $b } @closes;
    return \@closes;
}

=back

=head1 INSTANCE METHODS

=over 4

=item parse (STRING)

Parses STRING as the content of a debian/changelog file.

=cut

sub parse {
    my ($self, $contents) = @_;

    $self->errors([]);
    $self->entries([]);

    # careful with negative matching /m
    unless (
        $contents =~ m{^ \S+ \s* [(] [^\)]+ [)] \s* (?:[^ \t;]+ \s*)+ ; }mx) {

        push(@{$self->errors}, [1, 'not a Debian changelog']);
        return;
    }

    my @lines = split(/\n/, $contents);

    # based on /usr/lib/dpkg/parsechangelog/debian
    my $expect='first heading';
    my $entry = Lintian::Changelog::Entry->new;
    my $blanklines = 0;

    # to make unknown version unique, for id
    my $unknown_version_counter = 1;

    my $position = 1;
    for my $line (@lines) {

        # trim end
        $line =~ s/\s+\r?$//;

      #	print encode_utf*(sprintf(STDERR "%-39.39s %-39.39s\n",$expect,$line));
        if ($line
            =~ m/^(?<Source>\w[-+0-9a-z.]*) \((?<Version>[^\(\) \t]+)\)(?<Distribution>(?:\s+[-+0-9a-z.]+)+)\;\s*(?<kvpairs>.*)$/i
        ){
            my $source = $+{Source};
            my $version = $+{Version};
            my $distribution = $+{Distribution};
            my $kvpairs = $+{kvpairs};

            unless ($expect eq 'first heading'
                || $expect eq 'next heading or eof') {
                $entry->ERROR([
                    $position,
                    "found start of entry where expected $expect",$line
                ]);
                push @{$self->errors}, $entry->ERROR;
            }

            unless ($entry->is_empty) {
                $entry->Closes(find_closes($entry->Changes));

                push @{$self->entries}, $entry;
                $entry = Lintian::Changelog::Entry->new;
            }

            $entry->position($position);

            $entry->Header($line);

            $entry->Source($source);
            $entry->Version($version);

            $distribution =~ s/^\s+//;
            $entry->Distribution($distribution);

            my %kvdone;
            for my $kv (split(/\s*,\s*/,$kvpairs)) {
                $kv =~ m/^([-0-9a-z]+)\=\s*(.*\S)$/i
                  ||push @{$self->errors},
                  [$position,"bad key-value after ';': '$kv'"];
                my $k = ucfirst $1;
                my $v = $2;
                $kvdone{$k}++
                  && push @{$self->errors},
                  [$position,"repeated key-value $k"];
                if ($k eq 'Urgency') {
                    $v =~ m/^([-0-9a-z]+)((\s+.*)?)$/i
                      ||push @{$self->errors},
                      [$position,"badly formatted urgency value $v"];
                    $entry->Urgency($1);
                    $entry->Urgency_LC(lc($1));
                    $entry->Urgency_Comment($2);
                } elsif ($k =~ m/^X[BCS]+-/i) {
                    # Extensions - XB for putting in Binary,
                    # XC for putting in Control, XS for putting in Source
                    $entry->{$k}= $v;
                } else {
                    push @{$self->errors},
                      [$position,
                        "unknown key-value key $k - copying to XS-$k"];
                    $entry->{ExtraFields}{"XS-$k"} = $v;
                }
            }
            $expect= 'start of change data';
            $blanklines = 0;

        } elsif ($line =~ /^(?:;;\s*)?Local variables:/i) {
            last; # skip Emacs variables at end of file

        } elsif ($line =~ /^vim:/i) {
            last; # skip vim variables at end of file

        } elsif ($line =~ /^\$\w+:.*\$/) {
            next; # skip stuff that look like a CVS keyword

        } elsif ($line =~ /^\# /) {
            next; # skip comments, even that's not supported

        } elsif ($line =~ m{^/\*.*\*/}) {
            next; # more comments

        } elsif ($line
            =~ m/^(?:\w+\s+\w+\s+\d{1,2} \d{1,2}:\d{1,2}:\d{1,2}\s+[\w\s]*\d{4})\s+(?:.*)\s+[<\(](?:.*)[\)>]/
            || $line
            =~ m/^(?:\w+\s+\w+\s+\d{1,2},?\s*\d{4})\s+(?:.*)\s+[<\(](?:.*)[\)>]/
            || $line =~ m/^(?:\w[-+0-9a-z.]*) \((?:[^\(\) \t]+)\)\;?/i
            || $line =~ m/^(?:[\w.+-]+)[- ]\S+ Debian \S+/i
            || $line =~ m/^Changes from version (?:.*) to (?:.*):/i
            || $line =~ m/^Changes for [\w.+-]+-[\w.+-]+:?$/i
            || fc($line) eq fc('Old Changelog:')
            || $line =~ m/^(?:\d+:)?\w[\w.+~-]*:?$/) {
            # save entries on old changelog format verbatim
            # we assume the rest of the file will be in old format once we
            # hit it for the first time
            last;

        } elsif ($line =~ m/^\S/) {
            push @{$self->errors},
              [$position,'badly formatted heading line', $line];

        } elsif ($line
            =~ m/^ \-\- (?<name>.*) <(?<email>.*)>(?<sep>  ?)(?<date>(?:\w+\,\s*)?\d{1,2}\s+\w+\s+\d{4}\s+\d{1,2}:\d\d:\d\d\s+[-+]\d{4}(?:\s+\([^\\\(\)]\))?)$/
        ) {

            my $name = $+{name};
            my $email = $+{email};
            my $separator = $+{sep};
            my $date = $+{date};

            $expect eq 'more change data or trailer'
              || push @{$self->errors},
              [$position,"found trailer where expected $expect", $line];
            if ($separator ne $SPACE . $SPACE) {
                push @{$self->errors},
                  [$position,'badly formatted trailer line', $line];
            }
            $entry->Trailer($line);
            $entry->Maintainer("$name <$email>")
              unless length $entry->Maintainer;

            unless(length $entry->Date && defined $entry->Timestamp) {
                $entry->Date($date);
                $entry->Timestamp(str2time($date));
                unless (defined $entry->Timestamp) {
                    push @{$self->errors},
                      [$position,"could not parse date $date"];
                }
            }
            $expect = 'next heading or eof';

        } elsif ($line =~ m/^ \-\-/) {
            $entry->{ERROR}
              = [$position, 'badly formatted trailer line', $line];
            push @{$self->errors}, $entry->ERROR;
            #	    $expect = 'next heading or eof'
            #		if $expect eq 'more change data or trailer';

        } elsif ($line =~ m/^\s{2,}(\S)/) {
            $expect eq 'start of change data'
              || $expect eq 'more change data or trailer'
              || do {
                push @{$self->errors},
                  [$position,"found change data where expected $expect",$line];
                if (($expect eq 'next heading or eof')
                    && !$entry->is_empty) {
                    # lets assume we have missed the actual header line
                    $entry->Closes(find_closes($entry->Changes));

                    push @{$self->entries}, $entry;

                    $entry = Lintian::Changelog::Entry->new;
                    $entry->Source($UNKNOWN);
                    $entry->Distribution($UNKNOWN);
                    $entry->Urgency($UNKNOWN);
                    $entry->Urgency_LC($UNKNOWN);
                    $entry->Version($UNKNOWN . (++$unknown_version_counter));
                    $entry->Urgency_Comment($EMPTY);
                    $entry->ERROR([
                        $position,
                        "found change data where expected $expect",$line
                    ]);
                }
              };
            $entry->{'Changes'} .= (" \n" x $blanklines)." $line\n";
            if (!$entry->{Items} || $1 eq $ASTERISK) {
                $entry->{Items} ||= [];
                push @{$entry->{Items}}, "$line\n";
            } else {
                $entry->{'Items'}[-1] .= (" \n" x $blanklines)." $line\n";
            }
            $blanklines = 0;
            $expect = 'more change data or trailer';

        } elsif ($line !~ m/\S/) {
            next
              if $expect eq 'start of change data'
              || $expect eq 'next heading or eof';
            $expect eq 'more change data or trailer'
              || push @{$self->errors},
              [$position,"found blank line where expected $expect"];
            $blanklines++;

        } else {
            push @{$self->errors}, [$position, 'unrecognised line', $line];
            (        $expect eq 'start of change data'
                  || $expect eq 'more change data or trailer')
              && do {
                # lets assume change data if we expected it
                $entry->{'Changes'} .= (" \n" x $blanklines)." $line\n";
                if (!$entry->{Items}) {
                    $entry->{Items} ||= [];
                    push @{$entry->{Items}}, "$line\n";
                } else {
                    $entry->{'Items'}[-1] .= (" \n" x $blanklines)." $line\n";
                }
                $blanklines = 0;
                $expect = 'more change data or trailer';
                $entry->ERROR([$position, 'unrecognised line', $line]);
              };
        }

    } continue {
        ++$position;
    }

    $expect eq 'next heading or eof'
      || do {
        $entry->ERROR([$position, "found eof where expected $expect"]);
        push @{$self->errors}, $entry->ERROR;
      };

    unless ($entry->is_empty) {
        $entry->Closes(find_closes($entry->Changes));
        push @{$self->entries}, $entry;
    }

    return;
}

=item errors

=item entries

=cut

has errors => (is => 'rw', default => sub { [] });
has entries => (is => 'rw', default => sub { [] });

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

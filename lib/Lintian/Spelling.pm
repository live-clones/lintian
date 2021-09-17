# -*- perl -*-
# Lintian::Spelling -- Lintian spelling checks shared between multiple scripts

# Copyright © 2009 Russ Allbery
# Copyright © 2004 Marc Brockschmidt
# Copyright © 1998 Richard Braakman
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

package Lintian::Spelling;

use v5.20;
use warnings;
use utf8;

use Exporter qw(import);

our @EXPORT_OK = qw(
  check_spelling
  check_spelling_picky
);

use Carp qw(croak);
use Const::Fast;
use Unicode::UTF8 qw(encode_utf8);

const my $SPACE => q{ };
const my $DOUBLE_QUOTE => q{"};

=head1 NAME

Lintian::Spelling -- Lintian spell checks shared between multiple scripts

=head1 SYNOPSIS

    use Lintian::Spelling qw(check_spelling);

=head1 DESCRIPTION

This module provides functions to do some Lintian checks that need to be
done in multiple places.  There are certain low-level checks, such as
validating a maintainer name and e-mail address or checking spelling,
which apply in multiple situations and should be done in multiple checks
scripts or in checks scripts and the Lintian front-end.

The functions provided by this module issue tags directly, usually either
taking the tag name to issue as an argument or dynamically constructing
the tag name based on function parameters.  The caller is responsible for
ensuring that all tags are declared in the relevant *.desc file with
proper descriptions and other metadata.  The possible tags issued by each
function are described in the documentation for that function.

=head1 FUNCTIONS

=over 4

=item check_spelling(TEXT,[ EXCEPTIONS,] CODEREF)

Performs a spelling check of TEXT.  Call CODEREF once for each unique
misspelling with the following arguments:

=over 4

=item The misspelled word/phrase

=item The correct word/phrase

=back

If EXCEPTIONS is given, it will be used as a hash ref of exceptions.
Any lowercase word appearing as a key of this hash ref will never be
considered a spelling mistake (exception being if it is a part of a
multiword misspelling).

Returns the number of spelling mistakes found in TEXT.

=cut

my (%CORRECTIONS, @CORRECTIONS_MULTIWORD);

sub check_spelling {
    my ($profile, $text, $exceptions, $code_ref, $duplicate_check) = @_;

    croak encode_utf8('No profile')
      unless defined $profile;

    return 0 unless $text;
    if (not $code_ref and $exceptions and ref($exceptions) eq 'CODE') {
        $code_ref = $exceptions;
        $exceptions = {};
    } else {
        $exceptions //= {};
    }
    $duplicate_check //= 1;

    my (%seen, %duplicates, $last_word, $quoted);
    my $counter = 0;
    my $text_orig = $text;

    if (!%CORRECTIONS) {
        my $corrections_multiword
          = $profile->load_data('spelling/corrections-multiword', '\|\|');
        my $corrections = $profile->load_data('spelling/corrections', '\|\|');
        for my $misspelled ($corrections->all) {
            $CORRECTIONS{$misspelled} = $corrections->value($misspelled);
        }
        for my $misspelled_regex ($corrections_multiword->all) {
            my $correct = $corrections_multiword->value($misspelled_regex);
            push(@CORRECTIONS_MULTIWORD,
                [qr/\b($misspelled_regex)\b/, $correct]);
        }
    }

    $text =~ tr/[]//d;
    # Strip () except for "(s)" suffixes.
    $text =~ s/(\((?!s\))|(?<!\(s)\))//gi;
    $text =~ s/(\w-)\s*\n\s*/$1/;
    $text =~ tr/\r\n \t/ /s;
    $text =~ s/\s++/ /g;

    # trim both ends
    $text =~ s/^\s+|\s+$//g;

    for my $word (split($SPACE, $text)) {
        my $ends_with_punct = 0;
        my $q = $word =~ tr/"/"/;
        # Change quoting on "foo or foo" but not "foo".
        if ($q & 1) {
            $quoted = not $quoted;
        }
        $ends_with_punct = 1 if $word =~ s/[.,;:?!]+$//;

        if ($duplicate_check and defined($last_word) and $last_word eq $word) {
            # Avoid flagging words inside quoted text.
            $code_ref->("$word $word (duplicate word)", $word)
              if not $quoted
              and not $duplicates{$word}++
              and not $ends_with_punct
              and $text_orig !~ /\b$word\s*\($word\b/;
        }

        if ($word =~ m/^[A-Za-z]+$/ and not $ends_with_punct) {
            $last_word = $word;
        } else {
            $last_word = undef;
        }
        next if ($word =~ /^[A-Z]{1,5}\z/);
        # Some exceptions are based on case (e.g. "teH").
        next if exists($exceptions->{$word});
        my $lcword = lc $word;
        if (exists($CORRECTIONS{$lcword})
            &&!exists($exceptions->{$lcword})) {
            $counter++;
            my $correction = $CORRECTIONS{$lcword};
            if ($word =~ /^[A-Z]+$/) {
                $correction = uc $correction;
            } elsif ($word =~ /^[A-Z]/) {
                $correction = ucfirst $correction;
            }
            next if $seen{$lcword}++;
            $code_ref->($word, $correction);
        }
    }

    # Special case for correcting multi-word strings.
    for my $cm (@CORRECTIONS_MULTIWORD) {
        my ($oregex, $correction) = @{$cm};
        if ($text =~ $oregex) {
            my $word = $1;
            if ($word =~ /^[A-Z]+$/) {
                $correction = uc $correction;
            } elsif ($word =~ /^[A-Z]/) {
                $correction = ucfirst $correction;
            }
            $counter++;
            next if $seen{lc $word}++;
            $code_ref->(
                $DOUBLE_QUOTE . $word . $DOUBLE_QUOTE,
                $DOUBLE_QUOTE . $correction . $DOUBLE_QUOTE
            );
        }
    }

    return $counter;
}

=item check_spelling_picky(TEXT, CODEREF)

Performs a spelling check of TEXT.  Call CODEREF once for each unique
misspelling with the following arguments:

=over 4

=item The misspelled word/phrase

=item The correct word/phrase

=back

This method performs some pickier corrections - such as checking for common
capitalization mistakes - which would are not included in check_spelling as
they are not appropriate for some files, such as changelogs.

Returns the number of spelling mistakes found in TEXT.

=cut

sub check_spelling_picky {
    my ($profile, $text, $code_ref) = @_;

    croak encode_utf8('No profile')
      unless defined $profile;

    my %seen;
    my $counter = 0;
    my $corrections_case
      = $profile->load_data('spelling/corrections-case', '\|\|');

    # Check this first in case it's contained in square brackets and
    # removed below.
    if ($text =~ /meta\s+package/) {
        $counter++;
        $code_ref->('meta package', 'metapackage');
    }

    # Exclude text enclosed in square brackets as it could be a package list
    # or similar which may legitimately contain lower-cased versions of
    # the words.
    $text =~ s/\[.+?\]//sg;
    $text =~ tr/\r\n \t/ /s;
    $text =~ s/\s++/ /g;

    # trim both ends
    $text =~ s/^\s+|\s+$//g;

    for my $word (split(/\s+/, $text)) {
        $word =~ s/^\(|[).,?!:;]+$//g;
        if ($corrections_case->recognizes($word)) {
            $counter++;
            next if $seen{$word}++;
            $code_ref->($word, $corrections_case->value($word));
        }
    }

    return $counter;
}

=back

=head1 AUTHOR

Originally written by Russ Allbery <rra@debian.org> for Lintian.  Based on
code from checks scripts by Marc Brockschmidt and Richard Braakman.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

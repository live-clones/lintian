# -*- perl -*-
# Lintian::Check -- Lintian checks shared between multiple scripts

# Copyright (C) 2009 Russ Allbery
# Copyright (C) 2004 Marc Brockschmidt
# Copyright (C) 1998 Richard Braakman
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

package Lintian::Check;

use strict;
use warnings;

use Exporter qw(import);
use Email::Valid;

use Lintian::Data;
use Lintian::Tags qw(tag);

our $KNOWN_BOUNCE_ADDRESSES = Lintian::Data->new('fields/bounce-addresses');

our @EXPORT_OK = qw(check_maintainer check_spelling check_spelling_picky
  $known_shells_regex
);

=head1 NAME

Lintian::Check -- Lintian checks shared between multiple scripts

=head1 SYNOPSIS

    use Lintian::Check qw(check_maintainer);

    my ($maintainer, $field) = ('John Doe', 'uploader');
    check_maintainer ($maintainer, $field);

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

=item check_maintainer(MAINTAINER, FIELD)

Checks the maintainer name and address MAINTAINER for Policy compliance
and other issues.  FIELD is the context in which the maintainer name and
address was seen and should be one of C<maintainer> (the Maintainer field
in a control file), C<uploader> (the Uploaders field in a control file),
or C<changed-by> (the Changed-By field in a changes file).

The following tags may be issued by this function.  The string C<%s> in
the tags below will be replaced with the value of FIELD.

=over 4

=item %s-address-is-on-localhost

The e-mail address portion of MAINTAINER is at C<localhost> or some other
similar domain.

= item %s-address-is-root-user

The user (from email or username) of MAINTAINER is root.

=item %s-address-causes-mail-loops-or-bounces

The e-mail address portion of MAINTAINER or UPLOADER refers to the PTS
e-mail addresses  C<package@packages.debian.org> or
C<package@packages.qa.debian.org>, or, alternatively refers to a mailing
list which is known to bounce off-list mails sent by Debian role accounts.


=item %s-address-looks-weird

MAINTAINER may be syntactically correct, but it isn't conventionally
formatted.  Currently this tag is only issued for missing whitespace
between the name and the address.

=item %s-address-malformed

MAINTAINER doesn't fit the basic syntax of a maintainer name and address
as specified in Policy.

=item %s-address-missing

MAINTAINER does not contain an e-mail address in angle brackets (<>).

=item %s-name-missing

MAINTAINER does not contain a full name before the address, or the e-mail
address was not in angle brackets.

=item wrong-debian-qa-address-set-as-maintainer

MAINTAINER appears to be the Debian QA Group, but the e-mail address
portion is wrong for orphaned packages.  This tag is only issued for a
FIELD of C<maintainer>.

=item wrong-debian-qa-group-name

MAINTAINER appears to be the Debian QA Group, but the name portion is not
C<Debian QA Group>.  This tag is only issued for a FIELD of C<maintainer>.

=back

The last two tags are issued here rather than in a location more specific
to checks of the Maintainer control field because they take advantage of
the parsing done by the rest of the function.

=cut

sub check_maintainer {
    my ($maintainer, $field) = @_;

    # Do the initial parse.
    $maintainer =~ /^([^<\s]*(?:\s+[^<\s]+)*)?(\s*)(?:<(.+)>)?(.*)$/;
    my ($name, $del, $mail, $extra) = ($1, $2, $3, $4);
    if (not $mail and $name =~ m/@/) {
        # Name probably missing and address has no <>.
        $mail = $name;
        $name = undef;
    }

    # Some basic tests.
    my $malformed;
    # If there is something after the mail address OR if there is a
    # ">" after the last "@" in the mail it is malformed.  This
    # happens with "name <name <email>>", where $mail will be "name
    # <email>" (#640489).  Email::Valid->address (below) will accept
    # this in most cases (because that is generally valid), but we
    # only want Email::Valid to validate the "email" part and not the
    # name (Policy allows "." to be unqouted in names, Email::Valid
    # does not etc.).  Thus this check is to ensure we only pass the
    # "email"-part to Email::Valid.
    if ($extra or ($mail && $mail =~ m/\@[^\>\@]+\>[^\>\@]*$/o)) {
        tag "$field-address-malformed", $maintainer;
        $malformed = 1;
    }
    tag "$field-address-looks-weird", $maintainer
      if (not $del and $name and $mail);

    if (not $name) {
        tag "$field-name-missing", $maintainer;
    } else {
        if ($name eq 'root') {
            tag "$field-address-is-root-user", $maintainer;
        }
    }

    # Don't issue the malformed tag twice if we already saw problems.
    if (not $mail) {
        # Cannot be done accurately for uploaders due to changes with commas
        # (see #485705)
        tag "$field-address-missing", $maintainer unless $field eq 'uploader';
    } else {
        if (not $malformed and not Email::Valid->address($mail)) {
            # Either not a valid email or possibly missing a comma between
            # two entries.
            $malformed = 1;
            if ($mail =~ /^0/) {
                # Email::Valid does not handle emails starting with "0" too
                # well.  So replace it with a "1", which Email::Valid cannot
                # misinterpret as a "false-value".
                # - Fixed in libemail-valid-perl/0.187-2, this work around
                #   can be dropped when the fix is in stable.
                my $copy = $mail;
                $copy =~ s/^0/1/;
                $malformed = 0 if Email::Valid->address($copy);
            }
            tag "$field-address-malformed", $maintainer if $malformed;
        }
        if ($mail =~ /(?:localhost|\.localdomain|\.localnet)$/) {
            tag "$field-address-is-on-localhost", $maintainer;
        }
        if ($mail =~ /^root@/) {
            tag "$field-address-is-root-user", $maintainer;
        }

        if (
            ($field ne 'changed-by')
            and (  $mail =~ /\@packages\.(?:qa\.)?debian\.org/i
                or $KNOWN_BOUNCE_ADDRESSES->known($mail))
          ) {
            tag "$field-address-causes-mail-loops-or-bounces", $maintainer;
        }

        # Some additional checks that we only do for maintainer fields.
        if ($field eq 'maintainer') {
            if (
                ($mail eq 'debian-qa@lists.debian.org')
                or (    $name =~ /\bdebian\s+qa\b/i
                    and $mail ne 'packages@qa.debian.org')
              ) {
                tag 'wrong-debian-qa-address-set-as-maintainer',$maintainer;
            } elsif ($mail eq 'packages@qa.debian.org') {
                tag 'wrong-debian-qa-group-name', $maintainer
                  if ($name ne 'Debian QA Group');
            }
        }
    }
    return;
}

sub _tag {
    my @args = grep { defined($_) } @_;
    return tag(@args);
}

=item check_spelling(TAG, TEXT, FILENAME, EXCEPTION)

Performs a spelling check of TEXT, reporting TAG if any errors are found.

If FILENAME is given, it will be used as the first argument to TAG.

If EXCEPTION is given, it will be used as a hash ref of exceptions.
Any lowercase word appearing as a key of this hash ref will never be
considered a spelling mistake (exception being if it is a part of a
multiword misspelling).

Returns the number of spelling mistakes found in TEXT.

=cut

sub check_spelling {
    my ($tag, $text, $filename, $exceptions) = @_;
    return unless $text;

    my %seen;
    my $counter = 0;
    my $corrections = Lintian::Data->new('spelling/corrections', '\|\|');
    my $corrections_multiword
      = Lintian::Data->new('spelling/corrections-multiword', '\|\|');

    $text =~ s/[()\[\]]//g;
    $text =~ s/(\w-)\s*\n\s*/$1/;

    $exceptions = {} unless (defined($exceptions));

    for my $word (split(/\s+/, $text)) {
        $word =~ s/[.,;:?!]+$//;
        next if ($word =~ /^[A-Z]{1,5}\z/);
        # Some exceptions are based on case (e.g. "teH").
        next if exists($exceptions->{$word});
        my $lcword = lc $word;
        if ($corrections->known($lcword)
            &&!exists($exceptions->{$lcword})) {
            $counter++;
            my $correction = $corrections->value($lcword);
            if ($word =~ /^[A-Z]+$/) {
                $correction = uc $correction;
            } elsif ($word =~ /^[A-Z]/) {
                $correction = ucfirst $correction;
            }
            next if $seen{$lcword}++;
            _tag($tag, $filename, $word, $correction) if defined $tag;
        }
    }

    # Special case for correcting multi-word strings.
    for my $oregex ($corrections_multiword->all) {
        if ($text =~ m,\b($oregex)\b,) {
            my $word = $1;
            my $correction = $corrections_multiword->value($oregex);
            if ($word =~ /^[A-Z]+$/) {
                $correction = uc $correction;
            } elsif ($word =~ /^[A-Z]/) {
                $correction = ucfirst $correction;
            }
            $counter++;
            next if $seen{lc $word}++;
            _tag($tag, $filename, $word, $correction)
              if defined $tag;
        }
    }

    return $counter;
}

=item check_spelling_picky(TAG, TEXT, FILENAME)

Perform a spelling check of TEXT, reporting TAG if any mistakes are found.
This method performs some pickier corrections - such as checking for common
capitalization mistakes - which would are not included in check_spelling as
they are not appropriate for some files, such as changelogs.

If FILENAME is given, it will be used as the first argument to TAG.

Returns the number of spelling mistakes found in TEXT.

=cut

sub check_spelling_picky {
    my ($tag, $text, $filename) = @_;

    my %seen;
    my $counter = 0;
    my $corrections_case
      = Lintian::Data->new('spelling/corrections-case', '\|\|');

    # Check this first in case it's contained in square brackets and
    # removed below.
    if ($text =~ m,meta\s+package,) {
        $counter++;
        _tag($tag, $filename, 'meta package', 'metapackage')
          if defined $tag;
    }

    # Exclude text enclosed in square brackets as it could be a package list
    # or similar which may legitimately contain lower-cased versions of
    # the words.
    $text =~ s/\[.+?\]//sg;
    for my $word (split(/\s+/, $text)) {
        $word =~ s/^\(|[).,?!:;]+$//g;
        if ($corrections_case->known($word)) {
            $counter++;
            next if $seen{$word}++;
            _tag($tag, $filename, $word, $corrections_case->value($word))
              if defined $tag;
            next;
        }
    }

    return $counter;
}

=back

=head1 VARIABLES

=over 4

=item $known_shells_regex

Regular expression that matches names of any known shell.

=cut

our $known_shells_regex = qr'(?:[bd]?a|t?c|(?:pd|m)?k|z)?sh';

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

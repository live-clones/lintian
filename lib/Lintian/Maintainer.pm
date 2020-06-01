# -*- perl -*-
# Lintian::Maintainer -- Lintian maintainer hecks shared between multiple scripts

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

package Lintian::Maintainer;

use v5.20;
use warnings;
use utf8;

use Exporter qw(import);
use Email::Valid;

use Lintian::Data;

our $KNOWN_BOUNCE_ADDRESSES = Lintian::Data->new('fields/bounce-addresses');

our @EXPORT_OK = qw(check_maintainer);

=head1 NAME

Lintian::Maintainer -- Lintian checks shared between multiple scripts

=head1 SYNOPSIS

    use Lintian::Maintainer qw(check_maintainer);

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

=item %s-address-malformed

MAINTAINER doesn't fit the basic syntax of a maintainer name and address
as specified in Policy.

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

    my @tags;

    # Do the initial parse.
    $maintainer =~ /^([^<\s]*(?:\s+[^<\s]+)*)?(\s*)(?:<(.+)>)?(.*)$/;
    my ($name, $del, $mail, $extra) = ($1, $2, $3, $4);
    if (not $mail and $name =~ m/@/) {
        # Name probably missing and address has no <>.
        $mail = $name;
        $name = '';
    }

    # Some basic tests.
    my $malformed;
    # If there is something after the mail address OR if there is a
    # ">" after the last "@" in the mail it is malformed.  This
    # happens with "name <name <email>>", where $mail will be "name
    # <email>" (#640489).  Email::Valid->address (below) will accept
    # this in most cases (because that is generally valid), but we
    # only want Email::Valid to validate the "email" part and not the
    # name (Policy allows "." to be unquoted in names, Email::Valid
    # does not etc.).  Thus this check is to ensure we only pass the
    # "email"-part to Email::Valid.
    if ($extra or ($mail && $mail =~ /\@[^\>\@]+\>[^\>\@]*$/)) {
        push(@tags, ["$field-address-malformed", $maintainer]);
        $malformed = 1;
    }

    if (not $name) {
        push(@tags, ["$field-name-missing", $maintainer]);
    } else {
        if ($name eq 'root') {
            push(@tags, ["$field-address-is-root-user", $maintainer]);
        }
    }

    # Don't issue the malformed tag twice if we already saw problems.
    if ($mail) {
        if (not $malformed and not Email::Valid->address($mail)) {
            # Either not a valid email or possibly missing a comma between
            # two entries.
            push(@tags, ["$field-address-malformed", $maintainer]);
        }
        if ($mail =~ /(?:localhost|\.localdomain|\.localnet)$/) {
            push(@tags, ["$field-address-is-on-localhost", $maintainer]);
        }
        if ($mail =~ /^root@/) {
            push(@tags, ["$field-address-is-root-user", $maintainer]);
        }

        if (($field ne 'changed-by') and $KNOWN_BOUNCE_ADDRESSES->known($mail))
        {
            push(@tags,
                ["$field-address-causes-mail-loops-or-bounces", $maintainer]);
        }

        # Some additional checks that we only do for maintainer fields.
        if ($field eq 'maintainer') {
            if (
                ($mail eq 'debian-qa@lists.debian.org')
                or (    $name =~ /\bdebian\s+qa\b/i
                    and $mail ne 'packages@qa.debian.org')
            ) {
                push(@tags,
                    ['wrong-debian-qa-address-set-as-maintainer',$maintainer]);
            } elsif ($mail eq 'packages@qa.debian.org') {
                push(@tags, ['wrong-debian-qa-group-name', $maintainer])
                  if ($name ne 'Debian QA Group');
            }
        }

        # Changed-by specific tests.
        if ($field eq 'changed-by') {
            my $DERIVATIVE_CHANGED_BY
              = Lintian::Data->new('common/derivative-changed-by',
                qr/\s*~~\s*/, sub { $_[1]; });

            foreach my $re ($DERIVATIVE_CHANGED_BY->all) {
                next if $maintainer =~ m/$re/;
                my $explanation = $DERIVATIVE_CHANGED_BY->value($re);
                push(
                    @tags,
                    [
                        "$field-invalid-for-derivative", $maintainer,
                        "($explanation)"
                    ]);
            }
        }
    }

    return @tags;
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

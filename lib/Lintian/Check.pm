# -*- perl -*-
# Lintian::Check -- Lintian checks shared between multiple scripts

# Copyright (C) 2008 Russ Allbery
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

use Exporter ();
use Tags qw(tag);

our @ISA    = qw(Exporter);
our @EXPORT = qw(check_maintainer);

=head1 NAME

Lintian::Check -- Lintian checks shared between multiple scripts

=head1 SYNOPSIS

    use Lintian::Check qw(check_maintainer);

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
or C<changes> (the Changed-By field in a changes file).

The following tags may be issued by this function.  The string C<%s> in
the tags below will be replaced with the value of FIELD.

=over 4

=item %s-address-is-on-localhost

The e-mail address portion of MAINTAINER is at C<localhost> or some other
similar domain.

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

=item %s-not-full-name

The name portion of MAINTAINER is a single word.  This tag is not issued
for a FIELD of C<changes>.

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
    tag "$field-address-malformed", $maintainer
        if $extra;
    tag "$field-address-looks-weird", $maintainer
        if (not $del and $name and $mail);

    # Wookey really only has one name.  If we get more of these, consider
    # removing the check.  Skip the full name check for changes files as it's
    # not important there; we'll get it from the debian/control checks if
    # needed.
    if (not $name) {
        tag "$field-name-missing", $maintainer;
    } elsif ($name !~ /^\S+\s+\S+/ and $name ne 'Wookey') {
        tag "$field-not-full-name", $name
            if $field ne 'changes';
    }

    # This should really be done with Email::Valid.
    if (not $mail) {
        tag "$field-address-missing", $maintainer;
    } else {
	if ($mail !~ /^[^()<>@,;:\\\"\[\]]+@(\S+\.)+\S+/) {
            tag "$field-address-malformed", $maintainer;
	}
	if ($mail =~ /(?:localhost|\.localdomain|\.localnet)$/) {
            tag "$field-address-is-on-localhost", $maintainer;
	}

	# Some additional checks that we only do for maintainer fields.
	if ($field eq 'maintainer') {
            if ($mail eq 'debian-qa@lists.debian.org') {
                tag 'wrong-debian-qa-address-set-as-maintainer', $maintainer;
            } elsif ($mail eq 'packages@qa.debian.org') {
                tag 'wrong-debian-qa-group-name', $maintainer
                    if ($name ne 'Debian QA Group');
            }
	}
    }
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
# vim: syntax=perl sw=4 sts=4 ts=4 et shiftround

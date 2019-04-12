# Hey emacs! This is a -*- Perl -*- script!
# Lintian::Deb822Parser -- Perl utility functions for parsing deb822 files

# Copyright (C) 1998 Christian Schwarz
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

package Lintian::Deb822Parser;
use strict;
use warnings;
use autodie;

use constant {
    DCTRL_DEBCONF_TEMPLATE => 1,
    DCTRL_NO_COMMENTS => 2,
    DCTRL_COMMENTS_AT_EOL => 4,
};

our %EXPORT_TAGS = (constants =>
      [qw(DCTRL_DEBCONF_TEMPLATE DCTRL_NO_COMMENTS DCTRL_COMMENTS_AT_EOL)],);
our @EXPORT_OK = (qw(
      visit_dpkg_paragraph
      parse_dpkg_control
      read_dpkg_control
      read_dpkg_control_utf8
      ), @{ $EXPORT_TAGS{constants} });

use Exporter qw(import);

=head1 NAME

Lintian::Deb822Parser - Lintian's generic Deb822 parser functions

=head1 SYNOPSIS

 use Lintian::Deb822Parser qw(read_dpkg_control_utf8);
 
 my (@paragraphs);
 eval { @paragraphs = read_dpkg_control_utf8('some/debian/ctrl/file'); };
 if ($@) {
    # syntax error etc.
    die "ctrl/file: $@";
 }
 
 foreach my $para (@paragraphs) {
    my $value = $para->{'some-field'};
    if (defined $value) {
        # ...
    }
 }

=head1 DESCRIPTION

This module contains a number of utility subs that are nice to have,
but on their own did not warrant their own module.

Most subs are imported only on request.

=head2 Debian control parsers

At first glance, this module appears to contain several debian control
parsers.  In practise, there is only one real parser
(L</visit_dpkg_paragraph>) - the rest are convenience functions around
it.

If you have very large files (e.g. Packages_amd64), you almost
certainly want L</visit_dpkg_paragraph>.  Otherwise, one of the
convenience functions are probably what you are looking for.

=over 4

=item Use L<Lintian::Util/get_deb_info> when

You have a I<.deb> (or I<.udeb>) file and you want the control file
from it.

=item Use L<Lintian::Util/get_dsc_info> when

You have a I<.dsc> (or I<.changes>) file.  Alternative, it is also
useful if you have a control file and only care about the first
paragraph.

=item Use L</read_dpkg_control_utf8> or L</read_dpkg_control> when

You have a debian control file (such I<debian/control>) and you want
a number of paragraphs from it.

=item Use L</parse_dpkg_control> when

When you would have used L</read_dpkg_control_utf8>, except you have an
open filehandle rather than a file name.

=back

=head1 CONSTANTS

The following constants can be passed to the Debian control file
parser functions to alter their parsing flag.

=over 4

=item DCTRL_DEBCONF_TEMPLATE

The file should be parsed as debconf template.  These have slightly
syntax rules for whitespace in some cases.

=item DCTRL_NO_COMMENTS

The file do not allow comments.  With this flag, any comment in the
file is considered a syntax error.

=back

=head1 FUNCTIONS

=over 4

=item parse_dpkg_control(HANDLE[, FLAGS[, LINES]])

Reads a debian control file from HANDLE and returns a list of
paragraphs in it.  A paragraph is represented via a hashref, which
maps (lower cased) field names to their values.

FLAGS (if given) is a bitmask of the I<DCTRL_*> constants.  Please
refer to L</CONSTANTS> for the list of constants and their meaning.
The default value for FLAGS is 0.

If LINES is given, it should be a reference to an empty list.  On
return, LINES will be populated with a hashref for each paragraph (in
the same order as the returned list).  Each hashref will also have a
special key "I<START-OF-PARAGRAPH>" that gives the line number of the
first field in that paragraph.  These hashrefs will map the field name
of the given paragraph to the line number where the field name
appeared.

This is a convenience sub around L</visit_dpkg_paragraph> and can
therefore produce the same errors as it.  Please see
L</visit_dpkg_paragraph> for the finer semantics of how the
control file is parsed.

NB: parse_dpkg_control does I<not> close the handle for the caller.

=cut

sub parse_dpkg_control {
    my ($handle, $flags, $lines) = @_;
    my @result;
    my $c = sub {
        my ($para, $line) = @_;
        push @result, $para;
        push @$lines, $line if defined $lines;
    };
    visit_dpkg_paragraph($c, $handle, $flags);
    return @result;
}

=item visit_dpkg_paragraph (CODE, HANDLE[, FLAGS])

Reads a debian control file from HANDLE and passes each paragraph to
CODE.  A paragraph is represented via a hashref, which maps (lower
cased) field names to their values.

FLAGS (if given) is a bitmask of the I<DCTRL_*> constants.  Please
refer to L</CONSTANTS> for the list of constants and their meaning.
The default value for FLAGS is 0.

If the file is empty (i.e. it contains no paragraphs), the method will
contain an I<empty> list.  The deb822 contents may be inside a
I<signed> PGP message with a signature.

visit_dpkg_paragraph will require the PGP headers to be correct (if
present) and require that the entire file is covered by the signature.
However, it will I<not> validate the signature (in fact, the contents
of the PGP SIGNATURE part can be empty).  The signature should be
validated separately.

visit_dpkg_paragraph will pass paragraphs to CODE as they are
completed.  If CODE can process the paragraphs as they are seen, very
large control files can be processed without keeping all the
paragraphs in memory.

As a consequence of how the file is parsed, CODE may be passed a
number of (valid) paragraphs before parsing is stopped due to a syntax
error.

NB: visit_dpkg_paragraph does I<not> close the handle for the caller.

CODE is expected to be a callable reference (e.g. a sub) and will be
invoked as the following:

=over 4

=item CODE->(PARA, LINE_NUMBERS)

The first argument, PARA, is a hashref to the most recent paragraph
parsed.  The second argument, LINE_NUMBERS, is a hashref mapping each
of the field names to the line number where the field name appeared.
LINE_NUMBERS will also have a special key "I<START-OF-PARAGRAPH>" that
gives the line number of the first field in that paragraph.

The return value of CODE is ignored.

If the CODE invokes die (or similar) the error is propagated to the
caller.

=back


I<On syntax errors>, visit_dpkg_paragraph will call die with the
following string:

  "syntax error at line %d: %s\n"

Where %d is the line number of the issue and %s is one of:

=over

=item Duplicate field %s

The field appeared twice in the paragraph.

=item Continuation line outside a paragraph (maybe line %d should be " .")

A continuation line appears outside a paragraph - usually caused by an
unintended empty line before it.

=item Whitespace line not allowed (possibly missing a ".")

An empty continuation line was found.  This usually means that a
period is missing to denote an "empty line" in (e.g.) the long
description of a package.

=item Cannot parse line "%s"

Generic error containing the text of the line that confused the
parser.  Note that all non-printables in %s will be replaced by
underscores.

=item Comments are not allowed

A comment line appeared and FLAGS contained DCTRL_NO_COMMENTS.

=item PGP signature seen before start of signed message

A "BEGIN PGP SIGNATURE" header is seen and a "BEGIN PGP MESSAGE" has
not been seen yet.

=item Two PGP signatures (first one at line %d)

Two "BEGIN PGP SIGNATURE" headers are seen in the same file.

=item Unexpected %s header

A valid PGP header appears (e.g. "BEGIN PUBLIC KEY BLOCK").

=item Malformed PGP header

An invalid or malformed PGP header appears.

=item Expected at most one signed message (previous at line %d)

Two "BEGIN PGP MESSAGE" headers appears in the same message.

=item End of file but expected an "END PGP SIGNATURE" header

The file ended after a "BEGIN PGP SIGNATURE" header without being
followed by an "END PGP SIGNATURE".

=item PGP MESSAGE header must be first content if present

The file had content before PGP MESSAGE.

=item Data after the PGP SIGNATURE

The file had data after the PGP SIGNATURE block ended.

=item End of file before "BEGIN PGP SIGNATURE"

The file had a "BEGIN PGP MESSAGE" header, but no signature was
present.

=back

=cut

# Defined rstrip here to avoid having to depend on L::Util
# prototype for default to $_
sub rstrip (_) {  ## no critic (Subroutines::RequireFinalReturn)
    if (defined wantarray) {
        # unpack 'A*' is faster than s/\s++$//
        return unpack('A*', $_[0]);
    }
    $_[0] = unpack('A*', $_[0]);
    # void context, so no return needed here.
}

sub visit_dpkg_paragraph {
    my ($code, $CONTROL, $flags) = @_;
    $flags//=0;
    my $lines = {};
    my $section = {};
    my $open_section = 0;
    my $last_tag;
    my $debconf = $flags & DCTRL_DEBCONF_TEMPLATE;
    my $signed = 0;
    my $signature = 0;

    local $_;
    while (<$CONTROL>) {
        chomp;

        if (substr($_, 0, 1) eq '#') {
            next unless $flags & DCTRL_NO_COMMENTS;
            die "syntax error at line $.: Comments are not allowed.\n";
        }

        # empty line?
        if ($_ eq '' || (!$debconf && m/^\s*$/)) {
            if ($open_section) { # end of current section
                 # pass the current section to the handler
                $code->($section, $lines);
                $section = {};
                $lines = {};
                $open_section = 0;
            }
        }
        # pgp sig? Be strict here (due to #696230)
        # According to http://tools.ietf.org/html/rfc4880#section-6.2
        # The header MUST start at the beginning of the line and MUST NOT have
        # any other text (except whitespace) after the header.
        elsif (m/^-----BEGIN PGP SIGNATURE-----[ \r\t]*$/)
        { # skip until end of signature
            my $saw_end = 0;
            if (not $signed or $signature) {
                die join(q{ },
                    "syntax error at line $.:",
                    "PGP signature seen before start of signed message\n")
                  if not $signed;
                die join(q{ },
                    "syntax error at line $.:",
                    "Two PGP signatures (first one at line $signature)\n");
            }
            $signature = $.;
            while (<$CONTROL>) {
                if (m/^-----END PGP SIGNATURE-----[ \r\t]*$/o) {
                    $saw_end = 1;
                    last;
                }
            }
            # The "at line X" may seem a little weird, but it keeps the
            # message format identical.
            die join(q{ },
                "syntax error at line $.:",
                qq{End of file but expected an "END PGP SIGNATURE" header\n})
              unless $saw_end;
        }
        # other pgp control?
        elsif (m/^-----(?:BEGIN|END) PGP/) {
            # At this point it could be a malformed PGP header or one
            # of the following valid headers (RFC4880):
            #  * BEGIN PGP MESSAGE
            #    - Possibly a signed Debian CTRL, so okay (for now)
            #  * BEGIN PGP {PUBLIC,PRIVATE} KEY BLOCK
            #    - Valid header, but not a Debian CTRL file.
            #  * BEGIN PGP MESSAGE, PART X{,/Y}
            #    - Valid, but we don't support partial messages, so
            #      bail on those.

            unless (m/^-----BEGIN PGP SIGNED MESSAGE-----[ \r\t]*$/) {
                # Not a (full) PGP MESSAGE; reject.

                my $key = qr/(?:BEGIN|END) PGP (?:PUBLIC|PRIVATE) KEY BLOCK/;
                my $msgpart = qr{BEGIN PGP MESSAGE, PART \d+(?:/\d+)?};
                my $msg
                  = qr/(?:BEGIN|END) PGP (?:(?:COMPRESSED|ENCRYPTED) )?MESSAGE/;

                if (m/^-----($key|$msgpart|$msg)-----[ \r\t]*$/o) {
                    die "syntax error at line $.: Unexpected $1 header\n";
                } else {
                    die "syntax error at line $.: Malformed PGP header\n";
                }
            } else {
                if ($signed) {
                    die join(q{ },
                        "syntax error at line $.:",
                        'Expected at most one signed message',
                        "(previous at line $signed)\n");
                }
                if ($last_tag) {
                    # NB: If you remove this, keep in mind that it may
                    # allow two paragraphs to merge.  Consider:
                    #
                    # Field-P1: some-value
                    # -----BEGIN PGP SIGNATURE-----
                    #
                    # Field-P2: another value
                    #
                    # At the time of writing: If $open_section is
                    # true, it will remain so until the empty line
                    # after the PGP header.
                    die join(q{ },
                        "syntax error at line $.:",
                        'PGP MESSAGE header must be first',
                        "content if present\n");
                }
                $signed = $.;
            }

            # skip until the next blank line
            while (<$CONTROL>) {
                last if /^\s*$/o;
            }
        }
       # did we see a signature already?  We allow all whitespace/comment lines
       # outside the signature.
        elsif ($signature) {
            # Accept empty lines after the signature.
            next if m/^\s*$/;

            # NB: If you remove this, keep in mind that it may allow
            # two paragraphs to merge.  Consider:
            #
            # Field-P1: some-value
            # -----BEGIN PGP SIGNATURE-----
            # [...]
            # -----END PGP SIGNATURE-----
            # Field-P2: another value
            #
            # At the time of writing: If $open_section is true, it
            # will remain so until the empty line after the PGP
            # header.
            die "syntax error at line $.: Data after the PGP SIGNATURE\n";
        }
        # new empty field?
        elsif (m/^([^: \t]+):\s*$/o) {
            $lines->{'START-OF-PARAGRAPH'} = $. if not $open_section;
            $open_section = 1;

            my ($tag) = (lc $1);
            $section->{$tag} = '';
            $lines->{$tag} = $.;

            $last_tag = $tag;
        }
        # new field?
        elsif (m/^([^: \t]+):\s*(.*)$/o) {
            $lines->{'START-OF-PARAGRAPH'} = $. if not $open_section;
            $open_section = 1;

            # Policy: Horizontal whitespace (spaces and tabs) may occur
            # immediately before or after the value and is ignored there.
            my ($tag,$value) = (lc $1,$2);
            rstrip($value);
            if (exists $section->{$tag}) {
                # Policy: A paragraph must not contain more than one instance
                # of a particular field name.
                die "syntax error at line $.: Duplicate field $tag.\n";
            }
            $value =~ s/#.*$// if $flags & DCTRL_COMMENTS_AT_EOL;
            $section->{$tag} = $value;
            $lines->{$tag} = $.;

            $last_tag = $tag;
        }
        # continued field?
        elsif (m/^([ \t].*\S.*)$/o) {
            $open_section
              or die join(q{ },
                "syntax error at line $.:",
                'Continuation line outside a paragraph (maybe line',
                ($. - 1), qq{should be " .").\n});

            # Policy: Many fields' values may span several lines; in this case
            # each continuation line must start with a space or a tab.  Any
            # trailing spaces or tabs at the end of individual lines of a
            # field value are ignored.
            my $value = rstrip($1);
            $value =~ s/#.*$// if $flags & DCTRL_COMMENTS_AT_EOL;
            $section->{$last_tag} .= "\n" . $value;
        }
        # None of the above => syntax error
        else {
            my $message = "syntax error at line $.";
            if (m/^\s+$/) {
                $message
                  .= ": Whitespace line not allowed (possibly missing a \".\").\n";
            } else {
                # Replace non-printables and non-space characters with
                # "_" - just in case.
                s/[^[:graph:][:space:]]/_/go;
                $message .= ": Cannot parse line \"$_\"\n";
            }
            die $message;
        }
    }
    # pass the last section (if not already done).
    $code->($section, $lines) if $open_section;

    # Given the API, we cannot use this check to prevent any
    # paragraphs from being emitted to the code argument, so we might
    # as well just do this last.
    if ($signed and not $signature) {
        # The "at line X" may seem a little weird, but it keeps the
        # message format identical.
        die join(q{ },
            "syntax error at line $.:",
            qq{End of file before "BEGIN PGP SIGNATURE"\n"});
    }
}

=item read_dpkg_control_utf8(FILE[, FLAGS[, LINES]])

=item read_dpkg_control(FILE[, FLAGS[, LINES]])

This is a convenience function to ease using L</parse_dpkg_control>
with paths to files (rather than open handles).  The first argument
must be the path to a FILE, which should be read as a debian control
file.  If the file is empty, an empty list is returned.

Otherwise, this behaves like:

 use autodie;
 
 open(my $fd, '<:encoding(UTF-8)', FILE); # or '<'
 my @p = parse_dpkg_control($fd, FLAGS, LINES);
 close($fd);
 return @p;

This goes without saying that may fail with any of the messages that
L</parse_dpkg_control(HANDLE[, FLAGS[, LINES]])> do.  It can also emit
autodie exceptions if open or close fails.

=cut

sub read_dpkg_control {
    my ($file, $flags, $lines) = @_;

    open(my $CONTROL, '<', $file);
    my @data = parse_dpkg_control($CONTROL, $flags, $lines);
    close($CONTROL);

    return @data;
}

sub read_dpkg_control_utf8 {
    my ($file, $flags, $lines) = @_;

    open(my $CONTROL, '<:encoding(UTF-8)', $file);
    my @data = parse_dpkg_control($CONTROL, $flags, $lines);
    close($CONTROL);

    return @data;
}

=back

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

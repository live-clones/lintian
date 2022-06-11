# Hey emacs! This is a -*- Perl -*- script!
# Lintian::Deb822::Constants -- Perl utility functions for parsing deb822 files

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

package Lintian::Deb822::Constants;

use v5.20;
use warnings;
use utf8;

use constant {
    DCTRL_DEBCONF_TEMPLATE => 1,
    DCTRL_NO_COMMENTS => 2,
    DCTRL_COMMENTS_AT_EOL => 4,
};

our %EXPORT_TAGS = (constants =>
      [qw(DCTRL_DEBCONF_TEMPLATE DCTRL_NO_COMMENTS DCTRL_COMMENTS_AT_EOL)],);

our @EXPORT_OK = (@{ $EXPORT_TAGS{constants} });

use Exporter qw(import);

=head1 NAME

Lintian::Deb822::Constants - Lintian's generic Deb822 constants

=head1 SYNOPSIS

 use Lintian::Deb822::Constants qw(DCTRL_NO_COMMENTS);

=head1 DESCRIPTION

This module contains a number of utility subs that are nice to have,
but on their own did not warrant their own module.

Most subs are imported only on request.

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

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

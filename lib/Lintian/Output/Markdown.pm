# -*- perl -*-
#
# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2009 Russ Allbery
# Copyright © 2020-2021 Felix Lechner
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

package Lintian::Output::Markdown;

use v5.20;
use warnings;
use utf8;

use Exporter qw(import);

our @EXPORT_OK = qw(
  markdown_authority
  markdown_bug
  markdown_manual_page
  markdown_uri
  markdown_hyperlink
);

use Const::Fast;

const my $EMPTY => q{};
const my $SPACE => q{ };

=head1 NAME

Lintian::Output::Markdown - Lintian interface for markdown output

=head1 SYNOPSIS

    use Lintian::Output::Markdown;

=head1 DESCRIPTION

Lintian::Output::Markdown provides functions for Markdown output.

=head1 FUNCTIONS

=over 4

=item markdown_authority

=cut

sub markdown_authority {
    my ($volume_title, $volume_url, $section_key, $section_title,$section_url)
      = @_;

    my $directed_link;
    $directed_link = markdown_hyperlink($section_title, $section_url)
      if length $section_title
      && length $section_url;

    my $pointer;
    if (length $section_key) {

        if ($section_key =~ /^[A-Z]+$/ || $section_key =~ /^appendix-/) {
            $pointer = "Appendix $section_key";

        } elsif ($section_key =~ /^\d+$/) {
            $pointer = "Chapter $section_key";

        } else {
            $pointer = "Section $section_key";
        }
    }

    # overall manual.
    my $volume_link = markdown_hyperlink($volume_title, $volume_url);

    if (length $directed_link) {

        return "$directed_link ($pointer) in the $volume_title"
          if length $pointer;

        return "$directed_link in the $volume_title";
    }

    return "$pointer of the $volume_link"
      if length $pointer;

    return "the $volume_link";
}

=item markdown_bug

=cut

sub markdown_bug {
    my ($number) = @_;

    return markdown_hyperlink("Bug#$number","https://bugs.debian.org/$number");
}

=item markdown_manual_page

=cut

sub markdown_manual_page {
    my ($name, $section) = @_;

    my $url
      ="https://manpages.debian.org/cgi-bin/man.cgi?query=$name&amp;sektion=$section";
    my $hyperlink = markdown_hyperlink("$name($section)", $url);

    return "the $hyperlink manual page";
}

=item markdown_uri

=cut

sub markdown_uri {
    my ($scheme, $locator) = @_;

    my $url = "$scheme://$locator";

    # use plain path as label for files
    return markdown_hyperlink($locator, $url)
      if $scheme eq 'file';

    # or nothing for everything else
    return markdown_hyperlink($EMPTY, $url);
}

=item markdown_hyperlink

=cut

sub markdown_hyperlink {
    my ($text, $url) = @_;

    return $text
      unless length $url;

    return "<$url>"
      unless length $text;

    return "[$text]($url)";
}

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

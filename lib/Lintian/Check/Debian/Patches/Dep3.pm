# debian/patches/dep3 -- lintian check script -*- perl -*-

# Copyright (C) 2020 Felix Lechner
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Debian::Patches::Dep3;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any none);
use Syntax::Keyword::Try;
use Unicode::UTF8 qw(valid_utf8 decode_utf8);

use Lintian::Deb822;

const my $EMPTY => q{};

use Moo;
use namespace::clean;

with 'Lintian::Check';

use POSIX qw(strftime);
use Time::Local;
use constant {
    EPOCH_START_YEAR => 1900,
    START_MONTH => 1,
    END_MONTH => 12,
    START_DAY => 1,
    END_DAY => 31,
};

# It'd be better to describe as RFC3339, instead of ISO8601
# See https://ijmacd.github.io/rfc3339-iso8601/
sub check_wrong_rfc3339_date {
    my ($date) = @_;

    my ($year, $month, $day) = $date =~ /^(\d{4})-(\d{2})-(\d{2})$/;
    return 1 unless defined $year && defined $month && defined $day;

    # check if date is valid
    return 1
      if $year < EPOCH_START_YEAR
      || $month < START_MONTH
      || $month > END_MONTH
      || $day < START_DAY
      || $day > END_DAY;

    # check if date is convertible to epoch
    my $epoch = eval {
        Time::Local::timelocal(0, 0, 0, $day, $month - 1,
            $year - EPOCH_START_YEAR);
    };
    return 1 unless defined $epoch;

    # check if converted epoch matches original date
    my $formatted_date = strftime('%Y-%m-%d', localtime($epoch));
    return 1 if $formatted_date ne $date;

    return 0;
}

use URI;

# Check if the given string is a valid http/https URL
sub is_invalid_url {
    my ($url) = @_;
    my $uri = eval { URI->new($url) };
    return 1 unless $uri && $uri->can('scheme') && $uri->can('host');
    return 1 if $uri->scheme !~ /^https?$/i;

    return 0;
}

# Check URL is Debian BTS or salsa.debian.org
sub not_debian_url {
    my ($url) = @_;
    my $uri = eval { URI->new($url) };
    return 1 unless $uri && $uri->can('scheme') && $uri->can('host');

    return 1
      if $uri->scheme !~ /^https?$/i
      || $uri->host !~ /^(?:bugs|salsa)\.debian\.org$/i;

    return 0;
}

sub visit_patched_files {
    my ($self, $item) = @_;

    return
      unless $item->name =~ m{^debian/patches/};

    return
      unless $item->is_file;

    return
      if $item->name eq 'debian/patches/series'
      || $item->name eq 'debian/patches/README';

    my $bytes = $item->bytes;
    return
      unless length $bytes;

    my ($headerbytes) = split(/^---/m, $bytes, 2);

    return
      unless valid_utf8($headerbytes);

    my $header = decode_utf8($headerbytes);
    return
      unless length $header;

    my $deb822 = Lintian::Deb822->new;

    my @sections;
    try {
        @sections = $deb822->parse_string($header);

    } catch {
        return;
    }

    return
      unless @sections;

    # use last mention when present multiple times
    my $origin = $deb822->last_mention('Origin');
    my $forwarded = $deb822->last_mention('Forwarded');
    my $applied_upstream = $deb822->last_mention('Applied-Upstream');
    my $bug = $deb822->last_mention('Bug');
    my $bug_debian = $deb822->last_mention('Bug-Debian');
    my $description = $deb822->last_mention('Description');
    my $subject = $deb822->last_mention('Subject');
    my $author = $deb822->last_mention('Author');
    my $from = $deb822->last_mention('From');
    my $last_update = $deb822->last_mention('Last-Update');

    # Spec: https://dep-team.pages.debian.net/deps/dep3/

    # It must have "Description:" or "Subject:" field
    if (none { length }($description,$subject)) {
        $self->pointed_hint(
            'invalid-dep3-format-patch-no-description-and-subject',
            $item->pointer);
        return;
    }

    # "Origin (required except if Author (or From?) is present)"
    if (none { length }($origin,$author,$from)) {
        $self->pointed_hint('invalid-dep3-format-patch-no-origin',
            $item->pointer);
        return;
    }

    my $origin_template1
      = '(upstream|backport|vendor|other), (<patch-url>|commit:<commit-id>)';
    my $origin_template2 ='<vendor|upstream|other>, <url of original patch>';
    my $origin_email
      = ($origin =~ /([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})/);

    # chech whether it is template value or not
    if ($origin eq $origin_template1 || $origin eq $origin_template2) {
        $self->pointed_hint(
            'invalid-dep3-format-patch-origin-field-default-value',
            $item->pointer);
        # is it email address?
    } elsif ($origin_email //= $EMPTY) {
        $self->pointed_hint('dep3-format-patch-author-or-from-is-better',
            $item->pointer);
    }

    my ($category) = split(m{\s*,\s*}, $origin, 2);
    $category //= $EMPTY;

    $self->pointed_hint('patch-not-forwarded-upstream', $item->pointer)
      if (not any { $category eq $_ } qw(upstream backport))
      &&($forwarded eq 'no'
        || none { length } ($applied_upstream,$bug,$forwarded));

    # Check whether "Bug" field is appropriate value (= upstream URL)
    if (($bug //= $EMPTY) && is_invalid_url($bug)) {
        if ($bug eq '<url in upstream bugtracker>')  {
            $self->pointed_hint(
                'invalid-dep3-format-patch-bug-field-default-value',
                $item->pointer);
            # guess "#99999" would be Debian BTS number
        }elsif ($bug =~ /^#\d+$/) {
            $self->pointed_hint('invalid-dep3-format-patch-maybe-bug-debian',
                $item->pointer);
        }else {
            $self->pointed_hint(
                'invalid-dep3-format-patch-bug-not-contain-url',
                $item->pointer);
        }
    }

    # Check whether "Bug-Debian" field is appropriate value
    $self->pointed_hint('invalid-dep3-format-patch-wrong-bug-debian-url',
        $item->pointer)
      if (($bug_debian //= $EMPTY) && not_debian_url($bug_debian));

    # Check "Last-Update" field format
    $self->pointed_hint('invalid-dep3-format-patch-wrong-last-update',
        $item->pointer)
      if (($last_update //= $EMPTY)
        && check_wrong_rfc3339_date($last_update) );

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

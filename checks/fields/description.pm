# fields/description -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz
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

package Lintian::fields::description;

use v5.20;
use warnings;
use utf8;
use autodie;

use Encode qw(decode);

use Lintian::Data;
use Lintian::Spelling qw(check_spelling check_spelling_picky);

# Compared to a lower-case string, so it must be all lower-case
use constant DH_MAKE_PERL_TEMPLATE => 'this description was'
  . ' automagically extracted from the module by dh-make-perl';

use constant EMPTY => q{};

use Moo;
use namespace::clean;

with 'Lintian::Check';

my $PLANNED_FEATURES = Lintian::Data->new('description/planned-features');

sub spelling_tag_emitter {
    my ($self, @orig_args) = @_;
    return sub {
        return $self->tag(@orig_args, @_);
    };
}

sub installable {
    my ($self) = @_;

    my $pkg = $self->processable->name;
    my $type = $self->processable->type;
    my $processable = $self->processable;
    my $group = $self->group;

    my $tabs = 0;
    my $template = 0;
    my $unindented_list = 0;

    return
      unless $processable->fields->exists('Description');

    my $full_description= $processable->fields->untrimmed_value('Description');

    $self->tag('odd-mark-in-description', 'comma not followed by whitespace')
      if $full_description =~ /,\S/;

    $full_description =~ m/^([^\n]*)\n(.*)$/s;
    my ($synopsis, $extended) = ($1, $2);
    unless (defined $synopsis) {
        # The first line will always be completely stripped but
        # continuations may have leading whitespace.  Therefore we
        # have to strip $full_description to restore this property,
        # when we use it as a fall-back value of the synopsis.
        $synopsis = $full_description;

        # trim both ends
        $synopsis =~ s/^\s+|\s+$//g;

        $extended = EMPTY;
    }

    $extended //= EMPTY;

    if ($synopsis =~ m/^\s*$/) {
        $self->tag('description-synopsis-is-empty');
    } else {
        if ($synopsis =~ m/^\Q$pkg\E\b/i) {
            $self->tag('description-starts-with-package-name');
        }
        if ($synopsis =~ m/^(an?|the)\s/i) {
            $self->tag('description-synopsis-starts-with-article');
        }
        if ($synopsis =~ m/(.*\.)(?:\s*$|\s+\S+)/i) {
            $self->tag('synopsis-is-a-sentence',"\"$synopsis\"")
              unless $1 =~ m/\s+etc\.$/
              or $1 =~ m/\s+e\.?g\.$/
              or $1 =~ m/(?<!\.)\.\.\.$/;
        }
        if ($synopsis =~ m/\t/) {
            $self->tag('description-contains-tabs') unless $tabs++;
        }
        if ($synopsis =~ m/^missing\s*$/i) {
            $self->tag('description-is-debmake-template') unless $template++;
        } elsif ($synopsis =~ m/<insert up to 60 chars description>/) {
            $self->tag('description-is-dh_make-template') unless $template++;
        }
        if ($synopsis !~ m/\s/) {
            $self->tag('description-too-short', $synopsis);
        }
        my $pkg_fmt = lc $pkg;
        my $synopsis_fmt = lc $synopsis;
        # made a fuzzy match
        $pkg_fmt =~ s,[-_], ,g;
        $synopsis_fmt =~ s,[-_/\\], ,g;
        $synopsis_fmt =~ s,\s+, ,g;
        if ($pkg_fmt eq $synopsis_fmt) {
            $self->tag('description-is-pkg-name', $synopsis);
        }

        # We have to decode into UTF-8 to get the right length for the
        # length check.  If the changelog uses a non-UTF-8 encoding,
        # this will mangle it, but it doesn't matter for the length
        # check.
        if (length(decode('utf-8', $synopsis)) >= 80) {
            $self->tag('synopsis-too-long');
        }
    }

    my $flagged_homepage;
    my @lines = split(/\n/, $extended);

    # count starts for extended description
    my $position = 1;
    for my $line (@lines) {
        next
          if $line =~ /^ \.\s*$/;

        if ($position == 1) {
            my $firstline = lc $line;
            my $lsyn = lc $synopsis;
            if ($firstline =~ /^\Q$lsyn\E$/) {
                $self->tag('description-synopsis-is-duplicated');
            } else {
                $firstline =~ s/[^a-zA-Z0-9]+//g;
                $lsyn =~ s/[^a-zA-Z0-9]+//g;
                if ($firstline eq $lsyn) {
                    $self->tag('description-synopsis-is-duplicated');
                }
            }
        }

        if ($line =~ /^ \.\s*\S/ || $line =~ /^ \s+\.\s*$/) {
            $self->tag('description-contains-invalid-control-statement');
        } elsif ($line =~ /^ [\-\*]/) {
       # Print it only the second time.  Just one is not enough to be sure that
       # it's a list, and after the second there's no need to repeat it.
            $self->tag('possible-unindented-list-in-extended-description')
              if $unindented_list++ == 2;
        }

        if ($line =~ /\t/) {
            $self->tag('description-contains-tabs') unless $tabs++;
        }

        if ($line =~ m,^\s*Homepage: <?https?://,i) {
            $self->tag('description-contains-homepage');
            $flagged_homepage = 1;
        }

        if ($PLANNED_FEATURES->matches_any($line, 'i')) {
            $self->tag('description-mentions-planned-features',
                "(line $position)");
        }

        if (index(lc($line), DH_MAKE_PERL_TEMPLATE) != -1) {
            $self->tag('description-contains-dh-make-perl-template');
        }

        my $first_person = $line;
        while ($first_person
            =~ m/(?:^|\s)(I|[Mm]y|[Oo]urs?|mine|myself|me|us|[Ww]e)(?:$|\s)/) {
            my $word = $1;
            $first_person =~ s/\Q$word//;
            $self->tag('using-first-person-in-description',
                "line $position: $word");
        }

        if ($position == 1) {
            # checks for the first line of the extended description:
            if ($line =~ /^ \s/) {
                $self->tag('description-starts-with-leading-spaces');
            }
            if ($line =~ /^\s*missing\s*$/i) {
                $self->tag('description-is-debmake-template')
                  unless $template++;
            } elsif (
                $line =~ /<insert long description, indented with spaces>/) {
                $self->tag('description-is-dh_make-template')
                  unless $template++;
            }
        }

        $self->tag('extended-description-line-too-long', "line $position")
          if length decode('utf-8', $line) > 80;

    } continue {
        ++$position;
    }

    if ($type ne 'udeb') {
        if (@lines == 0) {
            # Ignore debug packages with empty "extended" description
            # "debug symbols for pkg foo" is generally descriptive
            # enough.
            $self->tag('extended-description-is-empty')
              if not $processable->is_pkg_class('debug');
        } elsif (@lines < 2 && $synopsis !~ /(?:dummy|transition)/i) {
            $self->tag('extended-description-is-probably-too-short')
              unless $processable->is_pkg_class('any-meta')
              or $pkg =~ m{-dbg\Z}xsm;
        } elsif ($extended =~ /^ \.\s*\n|\n \.\s*\n \.\s*\n|\n \.\s*\n?$/) {
            $self->tag('extended-description-contains-empty-paragraph');
        }
    }

    # Check for a package homepage in the description and no Homepage
    # field.  This is less accurate and more of a guess than looking
    # for the old Homepage: convention in the body.
    unless ($processable->fields->exists('Homepage') or $flagged_homepage) {
        if (
            $extended =~ /homepage|webpage|website|url|upstream|web\s+site
                         |home\s+page|further\s+information|more\s+info
                         |official\s+site|project\s+home/xi
            and $extended =~ m,\b(https?://[a-z0-9][^>\s]+),i
        ) {
            $self->tag('description-possibly-contains-homepage', $1);
        } elsif ($extended =~ m,\b(https?://[a-z0-9][^>\s]+)>?\.?\s*\z,i) {
            $self->tag('description-possibly-contains-homepage', $1);
        }
    }

    if ($synopsis) {
        check_spelling(
            $synopsis,
            $group->spelling_exceptions,
            $self->spelling_tag_emitter(
                'spelling-error-in-description-synopsis'));
        # Auto-generated dbgsym packages will use the package name in
        # their synopsis.  Unfortunately, some package names trigger a
        # capitalization error, such as "dbus" -> "D-Bus".  Therefore,
        # we exempt auto-generated packages from this check.
        check_spelling_picky(
            $synopsis,
            $self->spelling_tag_emitter(
                'capitalization-error-in-description-synopsis')
        )if not $processable->is_pkg_class('auto-generated');
    }

    if ($extended) {
        check_spelling(
            $extended,
            $group->spelling_exceptions,
            $self->spelling_tag_emitter('spelling-error-in-description'));
        check_spelling_picky($extended,
            $self->spelling_tag_emitter('capitalization-error-in-description')
        );
    }

    if ($pkg =~ /^lib(.+)-perl$/) {
        my $mod = $1;
        my @mod_path_elements = split(/-/, $mod);
        $mod = join('::', map {ucfirst} @mod_path_elements);
        my $mod_lc = lc($mod);

        my $pm_found = 0;
        my $pmpath = join('/', @mod_path_elements).'.pm';
        my $pm     = $mod_path_elements[-1].'.pm';

        foreach my $filepath ($processable->installed->sorted_list) {
            if ($filepath =~ m(\Q$pmpath\E\z|/\Q$pm\E\z)i) {
                $pm_found = 1;
                last;
            }
        }

        $self->tag('perl-module-name-not-mentioned-in-description', $mod)
          if (index(lc($extended), $mod_lc) < 0 and $pm_found);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

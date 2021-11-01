# fields/vcs -- lintian check script (rewrite) -*- perl -*-
#
# Copyright © 2004 Marc Brockschmidt
# Copyright © 2019 Chris Lamb <lamby@debian.org>
#
# Parts of the code were taken from the old check script, which
# was Copyright © 1998 Richard Braakman (also licensed under the
# GPL 2 or higher)
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

package Lintian::Check::Fields::Vcs;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $QUESTION_MARK => q{?};

my %VCS_EXTRACT = (
    Browser => sub { return @_;},
    Arch    => sub { return @_;},
    Bzr     => sub { return @_;},
    # cvs rootdir followed by optional module name:
    Cvs     => sub { return shift =~ /^(.+?)(?:\s+(\S*))?$/;},
    Darcs   => sub { return @_;},
    # hg uri followed by optional -b branchname
    Hg      => sub { return shift =~ /^(.+?)(?:\s+-b\s+(\S*))?$/;},
    # git uri followed by optional "[subdir]", "-b branchname" etc.
    Git     =>
      sub { return shift =~ /^(.+?)(?:\s+\[(\S*)\])?(?:\s+-b\s+(\S*))?$/;},
    Svn     => sub { return @_;},
    # New "mtn://host?branch" uri or deprecated "host branch".
    Mtn     => sub { return shift =~ /^(.+?)(?:\s+\S+)?$/;},
);

my %VCS_CANONIFY = (
    Browser => sub {
        $_[0] =~ s{https?://svn\.debian\.org/wsvn/}
                  {https://anonscm.debian.org/viewvc/};
        $_[0] =~ s{https?\Q://git.debian.org/?p=\E}
                  {https://anonscm.debian.org/git/};
        $_[0] =~ s{https?\Q://bzr.debian.org/loggerhead/\E}
                  {https://anonscm.debian.org/loggerhead/};
        $_[0] =~ s{https?\Q://salsa.debian.org/\E([^/]+/[^/]+)\.git/?$}
                  {https://salsa.debian.org/$1};

        if ($_[0] =~ m{https?\Q://anonscm.debian.org/viewvc/\E}xsm) {
            if ($_[0] =~ s{\?(.*[;\&])?op=log(?:[;\&](.*))?\Z}{}xsm) {
                my (@keep) = ($1, $2, $3);
                my $final = join($EMPTY, grep {defined} @keep);

                $_[0] .= $QUESTION_MARK . $final
                  if $final ne $EMPTY;

                $_[1] = 'vcs-field-bitrotted';
            }
        }
    },
    Cvs      => sub {
        if (
            $_[0] =~ s{\@(?:cvs\.alioth|anonscm)\.debian\.org:/cvsroot/}
                      {\@anonscm.debian.org:/cvs/}
        ) {
            $_[1] = 'vcs-field-bitrotted';
        }
        $_[0]=~ s{\@\Qcvs.alioth.debian.org:/cvs/}{\@anonscm.debian.org:/cvs/};
    },
    Arch     => sub {
        $_[0] =~ s{https?\Q://arch.debian.org/arch/\E}
                  {https://anonscm.debian.org/arch/};
    },
    Bzr     => sub {
        $_[0] =~ s{https?\Q://bzr.debian.org/\E}
                  {https://anonscm.debian.org/bzr/};
        $_[0] =~ s{https?\Q://anonscm.debian.org/bzr/bzr/\E}
                  {https://anonscm.debian.org/bzr/};
    },
    Git     => sub {
        if (
            $_[0] =~ s{git://(?:git|anonscm)\.debian\.org/~}
                      {https://anonscm.debian.org/git/users/}
        ) {
            $_[1] = 'vcs-git-uses-invalid-user-uri';
        }
        $_[0] =~ s{(https?://.*?\.git)(?:\.git)+$}{$1};
        $_[0] =~ s{https?\Q://git.debian.org/\E(?:git/?)?}
                  {https://anonscm.debian.org/git/};
        $_[0] =~ s{https?\Q://anonscm.debian.org/git/git/\E}
                  {https://anonscm.debian.org/git/};
        $_[0] =~ s{\Qgit://git.debian.org/\E(?:git/?)?}
                  {https://anonscm.debian.org/git/};
        $_[0] =~ s{\Qgit://anonscm.debian.org/git/\E}
                  {https://anonscm.debian.org/git/};
        $_[0] =~ s{https?\Q://salsa.debian.org/\E([^/]+/[^/\.]+)(?!\.git)$}
                  {https://salsa.debian.org/$1.git};
    },
    Hg      => sub {
        $_[0] =~ s{https?\Q://hg.debian.org/\E}
                  {https://anonscm.debian.org/hg/};
        $_[0] =~ s{https?\Q://anonscm.debian.org/hg/hg/\E}
                  {https://anonscm.debian.org/hg/};
    },
    Svn     => sub {
        $_[0] =~ s{\Qsvn://cvs.alioth.debian.org/\E}
                  {svn://anonscm.debian.org/};
        $_[0] =~ s{\Qsvn://svn.debian.org/\E}
                  {svn://anonscm.debian.org/};
        $_[0] =~ s{\Qsvn://anonscm.debian.org/svn/\E}
                  {svn://anonscm.debian.org/};
    },
);

# Valid URI formats for the Vcs-* fields
# currently only checks the protocol, not the actual format of the URI
my %VCS_RECOMMENDED_URIS = (
    Browser => qr{^https?://},
    Arch    => qr{^https?://},
    Bzr     => qr{^(?:lp:|(?:nosmart\+)?https?://)},
    Cvs     => qr{^:(?:pserver:|ext:_?anoncvs)},
    Darcs   => qr{^https?://},
    Hg      => qr{^https?://},
    Git     => qr{^(?:git|https?|rsync)://},
    Svn     => qr{^(?:svn|(?:svn\+)?https?)://},
    Mtn     => qr{^mtn://},
);

my %VCS_VALID_URIS = (
    Arch    => qr{^https?://},
    Bzr     => qr{^(?:sftp|(?:bzr\+)?ssh)://},
    Cvs     => qr{^(?:-d\s*)?:(?:ext|pserver):},
    Hg      => qr{^ssh://},
    Git     => qr{^(?:git\+)?ssh://|^[\w.]+@[a-zA-Z0-9.]+:[/a-zA-Z0-9.]},
    Svn     => qr{^(?:svn\+)?ssh://},
    Mtn     => qr{^[\w.-]+$},
);

sub always {
    my ($self) = @_;

    my $type = $self->processable->type;
    my $processable = $self->processable;

    # team-maintained = maintainer or uploaders field contains a mailing list
    my $is_teammaintained = 0;
    my $team_email = $EMPTY;
    # co-maintained = maintained by an informal group of people,
    # i. e. >= 1 uploader and not team-maintained
    my $is_comaintained = 0;
    my $is_maintained_by_individual = 1;
    my $num_uploaders = 0;
    for my $field (qw(Maintainer Uploaders)) {

        next
          unless $processable->fields->declares($field);

        my $maintainer = $processable->fields->unfolded_value($field);

        my $is_list
          = $maintainer =~ /\b(\S+\@lists(?:\.alioth)?\.debian\.org)\b/;
        if ($is_list) {
            $is_teammaintained = 1;
            $team_email = $1;
            $is_maintained_by_individual = 0;
        }

        if ($field eq 'Uploaders') {

            # check for empty field see  #783628
            $maintainer =~ s/,\s*,/,/g
              if $maintainer =~ m/,\s*,/;

            my @uploaders = map { split /\@\S+\K\s*,\s*/ }
              split />\K\s*,\s*/, $maintainer;

            $num_uploaders = scalar @uploaders;

            if (@uploaders) {
                $is_comaintained = 1
                  unless $is_teammaintained;
                $is_maintained_by_individual = 0;
            }

        }
    }

    $self->hint('package-is-team-maintained', $team_email,
        "(with $num_uploaders uploaders)")
      if $is_teammaintained;
    $self->hint('package-is-co-maintained', "(with $num_uploaders uploaders)")
      if $is_comaintained;
    $self->hint('package-is-maintained-by-individual')
      if $is_maintained_by_individual;

    my $KNOWN_VCS_HOSTERS= $self->profile->load_data(
        'fields/vcs-hosters',
        qr/\s*~~\s*/,
        sub {
            my @ret = split(m{,}, $_[1]);
            return \@ret;
        });

    my %seen_vcs;
    for my $platform (keys %VCS_EXTRACT) {

        my $splitter = $VCS_EXTRACT{$platform};

        my $fieldname = "Vcs-$platform";
        my $maintainer = $processable->fields->value('Maintainer');

        next
          unless $processable->fields->declares($fieldname);

        my $uri = $processable->fields->unfolded_value($fieldname);

        my @parts = $splitter->($uri);
        if (not @parts or not $parts[0]) {
            $self->hint('vcs-field-uses-unknown-uri-format', $platform, $uri);
        } else {
            if (    $VCS_RECOMMENDED_URIS{$platform}
                and $parts[0] !~ $VCS_RECOMMENDED_URIS{$platform}) {
                if (    $VCS_VALID_URIS{$platform}
                    and $parts[0] =~ $VCS_VALID_URIS{$platform}) {
                    $self->hint('vcs-field-uses-not-recommended-uri-format',
                        $platform, $uri);
                } else {
                    $self->hint('vcs-field-uses-unknown-uri-format',
                        $platform,$uri);
                }
            }

            $self->hint('vcs-field-has-unexpected-spaces', $platform, $uri)
              if (any { $_ and /\s/} @parts);

            $self->hint('vcs-field-uses-insecure-uri', $platform, $uri)
              if $parts[0] =~ m{^(?:git|(?:nosmart\+)?http|svn)://}
              || $parts[0] =~ m{^(?:lp|:pserver):};
        }

        if ($VCS_CANONIFY{$platform}) {

            my $canonicalized = $parts[0];
            my $tag = 'vcs-field-not-canonical';

            foreach my $canonify ($VCS_CANONIFY{$platform}) {
                $canonify->($canonicalized, $tag);
            }

            $self->hint($tag, $platform, $parts[0], $canonicalized)
              unless $canonicalized eq $parts[0];
        }

        if ($platform eq 'Browser') {

            $self->hint('vcs-browser-links-to-empty-view', $uri)
              if $uri =~ /rev=0&sc=0/;

        } else {
            $self->hint('vcs', lc $platform);
            $self->hint('vcs-uri', $platform, $uri);
            $seen_vcs{$platform}++;

            foreach my $regex ($KNOWN_VCS_HOSTERS->all) {
                foreach my $re_vcs (@{$KNOWN_VCS_HOSTERS->value($regex)}) {

                    if (   $uri =~ m/^($regex.*)/xi
                        && $platform ne $re_vcs
                        && $platform ne 'Browser') {

                        $self->hint('vcs-field-mismatch',
                            "Vcs-$platform != Vcs-$re_vcs",$uri);

                        # warn once
                        last;
                    }
                }
            }
        }

        if ($uri =~ m{//(.+)\.debian\.org/}) {
            $self->hint('vcs-obsolete-in-debian-infrastructure',
                $platform, $uri)
              unless $1 =~ m{^(?:salsa|.*\.dgit)$};

        }

        # orphaned
        if ($maintainer =~ /packages\@qa.debian.org/ && $platform ne 'Browser')
        {
            if ($uri =~ m{//(.+)\.debian\.org/}) {
                $self->hint('orphaned-package-maintained-in-private-space',
                    $fieldname, $uri)
                  unless $uri =~ m{//salsa\.debian\.org/debian/}
                  || $uri =~ m{//git\.dgit\.debian\.org/};
            } else {
                $self->hint(
                    'orphaned-package-not-maintained-in-debian-infrastructure',
                    $fieldname, $uri
                );
            }
        }

        $self->hint('old-dpmt-vcs', $platform)
          if $maintainer =~ m{python-modules-team\@lists\.alioth\.debian\.org}
          and $uri !~ m{salsa.debian.org/python-team/packages/.+};

        $self->hint('old-papt-vcs', $platform)
          if $maintainer =~ m{python-apps-team\@lists\.alioth\.debian\.org}
          and $uri !~ m{salsa.debian.org/python-team/packages/.+};
    }

    $self->hint('vcs-fields-use-more-than-one-vcs',
        (sort map { lc } keys %seen_vcs))
      if keys %seen_vcs > 1;

    $self->hint('co-maintained-package-with-no-vcs-fields')
      if $type eq 'source'
      and ($is_comaintained or $is_teammaintained)
      and not %seen_vcs;

    # Check for missing Vcs-Browser headers
    unless ($processable->fields->declares('Vcs-Browser')) {

        foreach my $regex ($KNOWN_VCS_HOSTERS->all) {

            my $platform = @{$KNOWN_VCS_HOSTERS->value($regex)}[0];
            my $fieldname = "Vcs-$platform";

            if ($processable->fields->value($fieldname)=~ m/^($regex.*)/xi){

                $self->hint('missing-vcs-browser-field', $fieldname, $1);

                # warn once
                last;
            }
        }
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

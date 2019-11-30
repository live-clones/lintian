# fields/vcs -- lintian check script (rewrite) -*- perl -*-
#
# Copyright (C) 2004 Marc Brockschmidt
#
# Parts of the code were taken from the old check script, which
# was Copyright (C) 1998 Richard Braakman (also licensed under the
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

package Lintian::fields::vcs;

use strict;
use warnings;
use autodie;

use List::MoreUtils qw(any);

use Lintian::Data ();

use constant EMPTY => q{};

use Moo;
use namespace::clean;

with 'Lintian::Check';

our $KNOWN_VCS_HOSTERS= Lintian::Data->new(
    'fields/vcs-hosters',
    qr/\s*~~\s*/,
    sub {
        my @ret = split(',', $_[1]);
        return \@ret;
    });

my %VCS_EXTRACT = (
    browser => sub { return @_;},
    arch    => sub { return @_;},
    bzr     => sub { return @_;},
    # cvs rootdir followed by optional module name:
    cvs     => sub { return shift =~ /^(.+?)(?:\s+(\S*))?$/;},
    darcs   => sub { return @_;},
    # hg uri followed by optional -b branchname
    hg      => sub { return shift =~ /^(.+?)(?:\s+-b\s+(\S*))?$/;},
    # git uri followed by optional "[subdir]", "-b branchname" etc.
    git     =>
      sub { return shift =~ /^(.+?)(?:\s+\[(\S*)\])?(?:\s+-b\s+(\S*))?$/;},
    svn     => sub { return @_;},
    # New "mtn://host?branch" uri or deprecated "host branch".
    mtn     => sub { return shift =~ /^(.+?)(?:\s+\S+)?$/;},
);

my %VCS_CANONIFY = (
    browser => sub {
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
                my $final = join('', grep {defined} @keep);
                $_[0] .= '?' . $final if ($final ne '');
                $_[1] = 'vcs-field-bitrotted';
            }
        }
    },
    cvs      => sub {
        if (
            $_[0] =~ s{\@(?:cvs\.alioth|anonscm)\.debian\.org:/cvsroot/}
                      {\@anonscm.debian.org:/cvs/}
        ) {
            $_[1] = 'vcs-field-bitrotted';
        }
        $_[0]=~ s{\@\Qcvs.alioth.debian.org:/cvs/}{\@anonscm.debian.org:/cvs/};
    },
    arch     => sub {
        $_[0] =~ s{https?\Q://arch.debian.org/arch/\E}
                  {https://anonscm.debian.org/arch/};
    },
    bzr     => sub {
        $_[0] =~ s{https?\Q://bzr.debian.org/\E}
                  {https://anonscm.debian.org/bzr/};
        $_[0] =~ s{https?\Q://anonscm.debian.org/bzr/bzr/\E}
                  {https://anonscm.debian.org/bzr/};
    },
    git     => sub {
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
    hg      => sub {
        $_[0] =~ s{https?\Q://hg.debian.org/\E}
                  {https://anonscm.debian.org/hg/};
        $_[0] =~ s{https?\Q://anonscm.debian.org/hg/hg/\E}
                  {https://anonscm.debian.org/hg/};
    },
    svn     => sub {
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
    browser => qr;^https?://;,
    arch    => qr;^https?://;,
    bzr     => qr;^(?:lp:|(?:nosmart\+)?https?://);,
    cvs     => qr;^:(?:pserver:|ext:_?anoncvs);,
    darcs   => qr;^https?://;,
    hg      => qr;^https?://;,
    git     => qr;^(?:git|https?|rsync)://;,
    svn     => qr;^(?:svn|(?:svn\+)?https?)://;,
    mtn     => qr;^mtn://;,
);

my %VCS_VALID_URIS = (
    arch    => qr;^https?://;,
    bzr     => qr;^(?:sftp|(?:bzr\+)?ssh)://;,
    cvs     => qr;^(?:-d\s*)?:(?:ext|pserver):;,
    hg      => qr;^ssh://;,
    git     => qr;^(?:git\+)?ssh://|^[\w.]+@[a-zA-Z0-9.]+:[/a-zA-Z0-9.];,
    svn     => qr;^(?:svn\+)?ssh://;,
    mtn     => qr;^[\w.-]+$;,
);

sub always {
    my ($self) = @_;

    my $type = $self->type;
    my $processable = $self->processable;

    # team-maintained = maintainer or uploaders field contains a mailing list
    my $is_teammaintained = 0;
    my $team_email = '';
    # co-maintained = maintained by an informal group of people,
    # i. e. >= 1 uploader and not team-maintained
    my $is_comaintained = 0;
    my $is_maintained_by_individual = 1;
    my $num_uploaders = 0;
    for my $field (qw(maintainer uploaders)) {

        my $maintainer = $processable->unfolded_field($field);

        next
          unless defined $maintainer;

        my $is_list = $maintainer =~ /\b(\S+\@lists(?:\.alioth)?\.debian\.org)\b/;
        if ($is_list) {
            $is_teammaintained = 1;
            $team_email = $1;
            $is_maintained_by_individual = 0;
        }

        if ($field eq 'uploaders') {

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

    $self->tag('package-is-team-maintained', $team_email, $num_uploaders)
      if $is_teammaintained;
    $self->tag('package-is-co-maintained', $num_uploaders)
      if $is_comaintained;
    $self->tag('package-is-maintained-by-individual')
      if $is_maintained_by_individual;

    my %seen_vcs;
    while (my ($platform, $splitter) = each %VCS_EXTRACT) {

        my $fieldname = "vcs-$platform";

        my $uri = $processable->unfolded_field($fieldname);

        next
          unless defined $uri;

        my @parts = &$splitter($uri);
        if (not @parts or not $parts[0]) {
            $self->tag('vcs-field-uses-unknown-uri-format', $fieldname, $uri);
        } else {
            if (    $VCS_RECOMMENDED_URIS{$platform}
                and $parts[0] !~ $VCS_RECOMMENDED_URIS{$platform}) {
                if (    $VCS_VALID_URIS{$platform}
                    and $parts[0] =~ $VCS_VALID_URIS{$platform}) {
                    $self->tag('vcs-field-uses-not-recommended-uri-format',
                        $fieldname, $uri);
                } else {
                    $self->tag('vcs-field-uses-unknown-uri-format',
                        $fieldname,$uri);
                }
            }

            $self->tag('vcs-field-has-unexpected-spaces', $fieldname, $uri)
              if (any { $_ and /\s/} @parts);

            $self->tag('vcs-field-uses-insecure-uri', $fieldname, $uri)
              if $parts[0] =~ m%^(?:git|(?:nosmart\+)?http|svn)://%
              || $parts[0] =~ m%^(?:lp|:pserver):%;
        }

        if ($VCS_CANONIFY{$platform}) {

            my $canonicalized = $parts[0];
            my $tag = 'vcs-field-not-canonical';

            foreach my $canonify ($VCS_CANONIFY{$platform}) {
                &$canonify($canonicalized, $tag);
            }

            $self->tag($tag, $parts[0], $canonicalized)
              unless $canonicalized eq $parts[0];
        }

        if ($platform eq 'browser') {

            $self->tag('vcs-browser-links-to-empty-view', $uri)
              if $uri =~ m%rev=0&sc=0%;

        } else {
            $self->tag('vcs', $platform);
            $self->tag('vcs-uri', $uri);
            $seen_vcs{$platform}++;

            foreach my $regex ($KNOWN_VCS_HOSTERS->all) {
                foreach my $re_vcs (@{$KNOWN_VCS_HOSTERS->value($regex)}) {

                    if (   $uri =~ m/^($regex.*)/xi
                        && $platform ne $re_vcs
                        && $platform ne 'browser') {

                        $self->tag('vcs-field-mismatch',
                            "vcs-$platform != vcs-$re_vcs",$uri);

                        # warn once
                        last;
                    }
                }
            }
        }

        if ($uri =~ m{//(.+)\.debian\.org/}) {
            $self->tag('vcs-obsolete-in-debian-infrastructure',
                $fieldname, $uri)
              unless $1 =~ m{^(?:salsa|.*\.dgit)$};

        } else {
            $self->tag(
                'orphaned-package-not-maintained-in-debian-infrastructure',
                $fieldname, $uri)
              if $processable->field('maintainer', EMPTY)
              =~ /packages\@qa.debian.org/
              && $platform ne 'browser';
        }
    }

    $self->tag('vcs-fields-use-more-than-one-vcs', sort keys %seen_vcs)
      if keys %seen_vcs > 1;

    $self->tag('co-maintained-package-with-no-vcs-fields')
      if $type eq 'source'
      and ($is_comaintained or $is_teammaintained)
      and not %seen_vcs;

    # Check for missing Vcs-Browser headers
    unless (defined $processable->field('vcs-browser')) {

        foreach my $regex ($KNOWN_VCS_HOSTERS->all) {

            my $platform = @{$KNOWN_VCS_HOSTERS->value($regex)}[0];
            my $fieldname = "vcs-$platform";

            if ($processable->field($fieldname, EMPTY) =~ m/^($regex.*)/xi) {
                $self->tag('missing-vcs-browser-field', $fieldname, $1);

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

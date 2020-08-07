#!/usr/bin/perl -w
#
# lintian-info -- transform lintian tags into descriptive text
#
# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2017 Chris Lamb <lamby@debian.org>
#
# This program is free software.  It is distributed under the terms of
# the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any
# later version.
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

package lintian_info;

use v5.20;
use warnings;
use utf8;

use Getopt::Long();

# turn file buffering off:
STDOUT->autoflush;

use Lintian::Data;
use Lintian::Profile;

sub compat();

my @RESTRICTED_CONFIG_DIRS= split(/:/, $ENV{'LINTIAN_RESTRICTED_CONFIG_DIRS'});
my @CONFIG_DIRS = split(/:/, $ENV{'LINTIAN_CONFIG_DIRS'});

sub load_profile {
    my ($profile_name, $options) = @_;
    my %opt = (
        'restricted-search-dirs' => \@RESTRICTED_CONFIG_DIRS,
        %{$options // {}},
    );
    require Lintian::Profile;

    my $profile = Lintian::Profile->new;
    $profile->load($profile_name, \@CONFIG_DIRS, \%opt);

    return $profile;
}

sub main {
    my ($annotate, $list_tags, $tags, $help, $prof);
    my (%already_displayed, $profile);
    my %opthash = (
        'annotate|a' => \$annotate,
        'list-tags|l' => \$list_tags,
        'tags|tag|t' => \$tags,
        'help|h' => \$help,
        'profile=s' => \$prof,
    );

    if (compat) {
        my $error = sub {
            die("The --$_[0] must be the first option if given\n");
        };
        $opthash{'include-dir=s'} = $error;
        $opthash{'user-dirs!'} = $error;
    }

    Getopt::Long::config('bundling', 'no_getopt_compat', 'no_auto_abbrev');
    Getopt::Long::GetOptions(%opthash) or die("error parsing options\n");

    # help
    if ($help) {
        my $me = 'lintian info';
        $me = 'lintian-info' if compat;
        print <<"EOT";
Usage: $me [log-file...] ...
       $me --annotate [overrides ...]
       $me --tags tag ...

Options:
    -a, --annotate     display descriptions of tags in Lintian overrides
    -l, --list-tags    list all tags Lintian knows about
    -t, --tag, --tags  display tag descriptions
    --profile X        use vendor profile X to determine severities
EOT
        if (compat) {
            # if we are called as lintian-info, we also accept
            # --include-dir and --[no-]user-dirs
            print <<'EOT';
    --include-dir DIR check for Lintian data in DIR
    --[no-]user-dirs  whether to include profiles from user directories

Note that --include-dir and --[no-]user-dirs must appear as the first
options if used.  Otherwise, they will trigger a deprecation warning.
EOT
        }

        exit 0;
    }

    $profile = load_profile($prof);

    Lintian::Data->set_vendor($profile);

    if ($list_tags) {
        foreach my $tag (sort $profile->enabled_tags) {
            print "$tag\n";
        }
        exit 0;
    }

    # If tag mode was specified, read the arguments as tags and display the
    # descriptions for each one.  (We don't currently display the severity,
    # although that would be nice.)
    if ($tags) {
        my $unknown = 0;
        for my $tag (@ARGV) {
            my $info = $profile->get_taginfo($tag);
            if ($info) {
                print $info->code . ": $tag\n";
                print "N:\n";
                print $info->description('text', 'N:   ');
            } else {
                print "N: $tag\n";
                print "N:\n";
                print "N:   Unknown tag.\n";
                $unknown = 1;
            }
            print "N:\n";
        }
        exit($unknown ? 1 : 0);
    }

    my $type_re = qr/(?:binary|changes|source|udeb)/;

    # Otherwise, read input files or STDIN, watch for tags, and add
    # descriptions whenever we see one, can, and haven't already
    # explained that tag.  Strip off color and HTML sequences.
    while (<>) {
        print;
        chomp;
        next if /^\s*$/;
        s/\e[\[\d;]*m//g;
        s/<span style=\"[^\"]+\">//g;
        s,</span>,,g;

        my $tag;
        if ($annotate) {
            my $tagdata;
            next unless m/^(?:                     # start optional part
                    (?:\S+)?                       # Optionally starts with package name
                    (?: \s*+ \[[^\]]+?\])?         # optionally followed by an [arch-list] (like in B-D)
                    (?: \s*+ $type_re)?            # optionally followed by the type
                  :\s++)?                          # end optional part
                ([\-\.a-zA-Z_0-9]+ (?:\s.+)?)$/x; # <tag-name> [extra] -> $1
            $tagdata = $1;
            ($tag, undef) = split / /, $tagdata, 2;
        } else {
            my @parts = split_tag($_);
            next unless @parts;
            $tag = $parts[5];
        }
        next if $already_displayed{$tag}++;
        my $info = $profile->get_taginfo($tag);
        next unless $info;
        print "N:\n";
        print $info->description('text', 'N:   ');
        print "N:\n";
    }
    exit(0);
}

{
    my $backwards_compat;

    sub compat() {
        return $backwards_compat if defined($backwards_compat);
        $backwards_compat = 0;
        if (exists($ENV{'LINTIAN_CALLED_AS'})) {
            my $called_as = $ENV{'LINTIAN_CALLED_AS'};
            $backwards_compat = 1
              if $called_as =~ m{ (?: \A | /) lintian-info \Z}xsm;
        }
        return $backwards_compat;
    }
}

=item split_tag

=cut

{
    # Matches something like:  (1:2.0-3) [arch1 arch2]
    # - captures the version and the architectures
    my $verarchre = qr,(?: \s* \(( [^)]++ )\) \s* \[ ( [^]]++ ) \]),xo;
    #                             ^^^^^^^^          ^^^^^^^^^^^^
    #                           ( version   )      [architecture ]

    # matches the full deal:
    #    1  222 3333  4444444   5555   666  777
    # -  T: pkg type (version) [arch]: tag [...]
    #           ^^^^^^^^^^^^^^^^^^^^^
    # Where the marked part(s) are optional values.  The numbers above
    # the example are the capture groups.
    my $TAG_REGEX
      = qr/([EWIXOPC]): (\S+)(?: (\S+)(?:$verarchre)?)?: (\S+)(?:\s+(.*))?/;

    sub split_tag {
        my ($tag_input) = @_;
        my $pkg_type;
        return unless $tag_input =~ /^${TAG_REGEX}$/;
        # default value...
        $pkg_type = $3//'binary';
        return ($1, $2, $pkg_type, $4, $5, $6, $7);
    }
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

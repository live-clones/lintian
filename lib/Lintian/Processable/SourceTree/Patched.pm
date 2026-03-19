# -*- perl -*- Lintian::Processable::Source::Patched
#
# Copyright (C) 2008 Russ Allbery
# Copyright (C) 2009 Raphael Geissert
# Copyright (C) 2020 Felix Lechner
# Copyright (C) 2025 Maytham Alsudany
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

package Lintian::Processable::SourceTree::Patched;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Cwd;
use List::SomeUtils qw(uniq);
use IPC::Run3;
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8 decode_utf8);

use Lintian::Index;
use Lintian::Index::Item;

const my $COLON => q{:};
const my $SLASH => q{/};
const my $NEWLINE => qq{\n};

const my $NO_UMASK => 0000;
const my $WAIT_STATUS_SHIFT => 8;

my $diff_ignore_default_regex = '
# Ignore general backup files
(?:^|/).*~$|
# Ignore emacs recovery files
(?:^|/)\.#.*$|
# Ignore vi swap files
(?:^|/)\..*\.sw.$|
# Ignore baz-style junk files or directories
(?:^|/),,.*(?:$|/.*$)|
# File-names that should be ignored (never directories)
(?:^|/)(?:DEADJOE|\.arch-inventory|\.(?:bzr|cvs|hg|git|mtn-)ignore)$|
# File or directory names that should be ignored
(?:^|/)(?:CVS|RCS|\.deps|\{arch\}|\.arch-ids|\.svn|
\.hg(?:tags|sigs)?|_darcs|\.git(?:attributes|modules|review)?|
\.mailmap|\.shelf|_MTN|\.be|\.bzr(?:\.backup|tags)?)(?:$|/.*$)|
# dh_clean defaults
^debian/debhelper-build-stamp$|
^debian/.*substvars$|
^debian/.*\.debhelper(\.log)?$|
^debian/\.debhelper(?:$|/.*$)
';
# Take out comments and newlines
$diff_ignore_default_regex =~ s/^#.*$//mg;
$diff_ignore_default_regex =~ s/\n//sg;

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Processable::SourceTree::Patched - access to sources with Debian patches applied

=head1 SYNOPSIS

    use Lintian::Processable;

=head1 DESCRIPTION

Lintian::Processable::SourceTree::Patched provides an
interface to collected data about patched sources.

=head1 INSTANCE METHODS

=over 4

=item patched

Returns a index object representing a patched source tree.

=cut

has patched => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my $index = Lintian::Index->new;
        my $archive = $self->basename;
        $index->identifier("$archive (source tree)");
        $index->basedir($self->basedir . $SLASH . 'unpacked');

        # source packages can be unpacked anywhere; no anchored roots
        $index->anchored(0);

        path($index->basedir)->remove_tree
          if -d $index->basedir;
        path($index->basedir)->mkdir;

        print encode_utf8("N: Copying source tree\n")
          if $ENV{'LINTIAN_DEBUG'};

        my $saved_umask = umask;
        umask $NO_UMASK;

        my $iter = $self->path->iterator({ recurse => 1 });
        while ( my $path = $iter->() ) {
          my $relative_path = $path->relative($self->path);
          next if $relative_path =~ $diff_ignore_default_regex;
          my $dest_path = path($index->basedir)->child($relative_path);
          if ($path->is_dir) {
            $dest_path->mkdir;
            next;
          }
          $path->copy($dest_path);
        }

        umask $saved_umask;

        my $index_errors = $index->create_from_basedir;

        my $savedir = getcwd;
        chdir($index->basedir)
          or die encode_utf8('Cannot change to directory ' . $index->basedir);

        # fix permissions
        my @permissions_command
          = ('chmod', '-R', 'u+rwX,o+rX,o-w', $index->basedir);
        my $permissions_errors;

        run3(\@permissions_command, \undef, \undef, \$permissions_errors);

        $permissions_errors = decode_utf8($permissions_errors)
          if length $permissions_errors;

        chdir($savedir)
          or die encode_utf8("Cannot change to directory $savedir");

        return $index;
    }
);

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

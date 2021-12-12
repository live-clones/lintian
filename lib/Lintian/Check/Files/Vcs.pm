# files/vcs -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
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

package Lintian::Check::Files::Vcs;

use v5.20;
use warnings;
use utf8;

use Const::Fast;

const my $VERTICAL_BAR => q{|};

use Moo;
use namespace::clean;

with 'Lintian::Check';

# an OR (|) regex of all vcs files
has VCS_PATTERNS_ORED => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        my @vcs_patterns;

        my $COMPRESS_FILE_EXTENSIONS
          = $self->data->load('files/compressed-file-extensions',qr/\s+/);

        my @quoted_extension_patterns
          = map { quotemeta } $COMPRESS_FILE_EXTENSIONS->all;
        my $ored_extension_patterns= ored_patterns(@quoted_extension_patterns);

        my $VCS_CONTROL_PATTERNS
          = $self->data->load('files/vcs-control-files', qr/\s+/);

        for my $pattern ($VCS_CONTROL_PATTERNS->all) {
            $pattern =~ s/\$[{]COMPRESS_EXT[}]/(?:$ored_extension_patterns)/g;
            push(@vcs_patterns, $pattern);
        }

        my $ored_vcs_patterns = ored_patterns(@vcs_patterns);

        return $ored_vcs_patterns;
    });

sub ored_patterns {
    my (@patterns) = @_;

    my @protected = map { "(?:$_)" } @patterns;

    my $ored = join($VERTICAL_BAR, @protected);

    return $ored;
}

sub visit_installed_files {
    my ($self, $file) = @_;

    if ($file->is_file) {

        my $pattern = $self->VCS_PATTERNS_ORED;

        $self->hint('package-contains-vcs-control-file', $file->name)
          if $file->name =~ m{$pattern}x
          && $file->name !~ m{^usr/share/cargo/registry/};

        if ($file->name =~ m/svn-commit.*\.tmp$/) {
            $self->hint('svn-commit-file-in-package', $file->name);
        }

        if ($file->name =~ m/svk-commit.+\.tmp$/) {
            $self->hint('svk-commit-file-in-package', $file->name);
        }

    } elsif ($file->is_dir) {

        $self->hint('package-contains-vcs-control-dir', $file->name)
          if $file->name =~ m{/CVS/?$}
          || $file->name =~ m{/\.(?:svn|bzr|git|hg)/?$}
          || $file->name =~ m{/\.arch-ids/?$}
          || $file->name =~ m{/\{arch\}/?$};
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

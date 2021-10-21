# debian/patches -- lintian check script -*- perl -*-
#
# Copyright © 2007 Marc Brockschmidt
# Copyright © 2008 Raphael Hertzog
# Copyright © 2018-2019 Chris Lamb <lamby@debian.org>
# Copyright © 2020 Felix Lechner
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

package Lintian::Check::Debian::Patches::Dpatch;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SPACE => q{ };

sub source {
    my ($self) = @_;

    my $build_deps = $self->processable->relation('Build-Depends-All');
    return
      unless $build_deps->satisfies('dpatch');

    my $patch_dir
      = $self->processable->patched->resolve_path('debian/patches/');
    return
      unless defined $patch_dir;

    $self->hint('package-uses-deprecated-dpatch-patch-system');

    my @list_files
      = grep {$_->basename =~ m/^00list/ && $_->is_open_ok}
      $patch_dir->children;

    $self->hint('dpatch-build-dep-but-no-patch-list')
      unless @list_files;

    my $options_file = $patch_dir->resolve_path('00options');

    my $list_uses_cpp = 0;
    $list_uses_cpp = 1
      if defined $options_file
      && $options_file->decoded_utf8 =~ /DPATCH_OPTION_CPP=1/;

    for my $file (@list_files) {
        my @patches;

        open(my $fd, '<', $file->unpacked_path)
          or die encode_utf8('Cannot open ' . $file->unpacked_path);

        while(my $line = <$fd>) {
            chomp $line;

            #ignore comments or CPP directive
            next
              if $line =~ /^\#/;

            # remove C++ style comments
            $line =~ s{//.*}{}
              if $list_uses_cpp;

            if ($list_uses_cpp && $line =~ m{/\*}) {

                # remove C style comments
                $line .= <$fd> while ($line !~ m{\*/});

                $line =~ s{/\*[^*]*\*/}{}g;
            }

            #ignore blank lines
            next
              if $line =~ /^\s*$/;

            push @patches, split($SPACE, $line);
        }
        close($fd);

        for my $patch_name (@patches) {

            my $patch_file = $patch_dir->child($patch_name);
            $patch_file = $patch_dir->child("${patch_name}.dpatch")
              unless defined $patch_file;

            unless (defined $patch_file) {
                $self->hint('dpatch-index-references-non-existent-patch',
                    $patch_name);
                next;
            }

            next
              unless $patch_file->is_open_ok;

            my $description = $EMPTY;
            open(my $fd, '<', $patch_file->unpacked_path)
              or die encode_utf8('Cannot open ' . $patch_file->unpacked_path);

            while (my $line = <$fd>) {
                # stop if something looking like a patch
                # starts:
                last
                  if $line =~ /^---/;
                # note comment if we find a proper one
                $description .= $1
                  if $line =~ /^\#+\s*DP:\s*(\S.*)$/
                  && $1 !~ /^no description\.?$/i;
                $description .= $1
                  if $line =~ /^\# (?:Description|Subject): (.*)/;
            }
            close($fd);

            $self->hint('dpatch-missing-description', $patch_name)
              unless length $description;
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

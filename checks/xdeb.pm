# xdeb -- lintian check script  -*- perl -*-

#  Copyright © 2008  Neil Williams <codehelp@debian.org>
#  Copyright © 2020  Felix Lechner <felix.lechner@lease-up.com>
#
#  This package is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

# This started as a cut-down version of the Emdebian Lintian check script.

package Lintian::xdeb;

use strict;
use warnings;

use constant EMPTY => q{};

use Moo;
use namespace::clean;

with 'Lintian::Check';

# need to make this table more accessible in Debian::DpkgCross
# and then do the comparison in that module (which can migrate into
# dpkg-dev).
our %elfpattern = (
    'i386' => qr/ELF 32-bit LSB .* 80386/,
    'sparc' => qr/ELF 32-bit MSB .* SPARC/,
    'sparc64' => qr/'ELF 64-bit MSB .* SPARC/,
    'alpha' => qr/ELF 64-bit LSB .* Alpha/,
    'm68k' => qr/ELF 32-bit MSB .* 680[02]0/,
    'arm' => qr/ELF 32-bit LSB .* ARM/,
    'armeb' => qr/ELF 32-bit MSB .* ARM/,
    'armel' => qr/ELF 32-bit LSB .* ARM/,
    'armhf' => qr/ELF 32-bit LSB .* ARM/,
    'powerpc' => qr/ELF 32-bit MSB .* PowerPC/,
    'powerpc64' => qr/ELF 64-bit MSB .* PowerPC/,
    'mips' => qr/ELF 32-bit MSB .* MIPS/,
    'mipsel' => qr/ELF 32-bit LSB .* MIPS/,
    'hppa' => qr/ELF 32-bit MSB .* PA-RISC/,
    's390' => qr/ELF 32-bit MSB .* S.390/,
    's390x' => qr/ELF 64-bit MSB .* S.390/,
    'ia64' => qr/ELF 64-bit LSB .* IA-64/,
    'm32r' => qr/ELF 32-bit MSB .* M32R/,
    'amd64' => qr/ELF 64-bit LSB .* x86-64/,
    'w32-i386' => qr/80386 COFF/,
    'AR' => qr/current ar archive/
);

# currently unused, pending changes in lintian.
sub set {
    my ($self) = @_;

    my $build = qx{dpkg-architecture -qDEB_BUILD_ARCH};
    chomp $build;

    if ($self->package =~ /locale/) {
        # $tags->suppress ("extended-description-is-empty");
        # $tags->suppress ("no-md5sums-control-file");
        # $tags->suppress ("no-copyright-file");

        # need TDeb checks here.
        # $tags->suppress ("debian-rules-missing-required-target *");

        # might want to fix this one.
        # $tags->suppress ("debian-files-list-in-source");
        # $tags->suppress ("native-package-with-dash-version");

        return;
    }

    # $tags->suppress ("no-copyright-file");
    # $tags->suppress ("python-script-but-no-python-dep");
    # $tags->suppress ("binary-without-manpage");
    # $tags->suppress ("binary-or-shlib-defines-rpath");
    # $tags->suppress ("build-depends-indep-without-arch-indep");

    return;
}

sub source {
    my ($self) = @_;

    # $tags->suppress ("debian-rules-missing-required-target");

    # # might want to fix this one.
    # $tags->suppress ("debian-files-list-in-source");
    # $tags->suppress ("native-package-with-dash-version");
    # $tags->suppress ("build-depends-indep-without-arch-indep");
    # $tags->suppress ("source-nmu-has-incorrect-version-number");
    # $tags->suppress ("changelog-should-mention-nmu");

    return;
}

# there are problems with some of these tests - the number of results
# is higher than the number of detections because certain tests get
# repeated for unrelated files unpacked alongside problematic files.

sub setup {
    my ($self) = @_;

    # $tags->suppress ("no-copyright-file");
    # $tags->suppress ("python-script-but-no-python-dep");
    # $tags->suppress ("binary-without-manpage");

    # $tags->suppress ("binary-or-shlib-defines-rpath");
    # $tags->suppress ("build-depends-indep-without-arch-indep");

    return;
}

sub files {
    my ($self, $file) = @_;

    return
      unless $file->is_file;

    # binary or object file?
    return
      unless $file->file_info =~ m/^[^,]*\bELF\b/;

    my $package = $self->processable->name;
    my $architecture = $self->processable->field('architecture');
    return
      unless defined $architecture;

    # not implemented
    my %RPATH;

    # rpath is mandatory when cross building
    my @rpaths = split(/:/, $RPATH{$file} // EMPTY);

    my @nomodules
      = grep { !m{^/usr/lib/(?:games/)?\Q$package\E(?:/|\z)} } @rpaths;

    # $self->tag('binary-or-shlib-omits-rpath', $file, $RPATH{$file})
    #   unless scalar @nomodules;

    my $pattern = $elfpattern{$architecture};

    $self->tag('binary-is-wrong-architecture', $file)
      if defined $pattern && $file->file_info !~ /$pattern/;

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

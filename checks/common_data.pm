#! /usr/bin/perl -w

package common_data;
use base qw(Exporter);

our @EXPORT = qw
(
   %known_archs %known_sections %known_non_us_parts %known_archive_parts
   %known_prios %known_source_fields %known_binary_fields %known_udeb_fields
   %known_obsolete_fields %known_essential %known_build_essential
   %known_obsolete_packages %known_obsolete_emacs %known_virtual_packages
   %known_libstdcs %known_tcls %known_tclxs %known_tks %known_tkxs
   %known_libpngs %known_x_metapackages
   %non_standard_archs %all_cpus %all_oses
   %known_doc_base_formats
);

# To let "perl -cw" test know we use these variables;
use vars qw
(
  %known_archs %known_sections %known_non_us_parts %known_archive_parts
  %known_prios %known_source_fields %known_binary_fields %known_udeb_fields
  %known_obsolete_fields %known_essential %known_build_essential
  %known_obsolete_packages %known_obsolete_emacs %known_virtual_packages
  %known_libstdcs %known_tcls %known_tclxs %known_tks %known_tkxs
  %known_libpngs %known_x_metapackages
  %non_standard_archs %all_cpus %all_oses
  %known_doc_base_formats
);

# simple defines for commonly needed data

# From /usr/share/dpkg/archtable, included here to make lintian results
# consistent no matter what dpkg one has installed.
%known_archs = map { $_ => 1 }
    ('i386', 'ia64', 'alpha', 'amd64', 'arm', 'hppa', 'm68k', 'mips',
     'mipsel', 'powerpc', 's390', 'sparc', 'hurd-i386', 'any', 'all');

# From /usr/share/dpkg/cputable, included here to make lintian results
# consistent no matter what dpkg one has installed.
%all_cpus = map { $_ => 1 }
    ('i386', 'ia64', 'alpha', 'amd64', 'armeb', 'arm', 'hppa', 'm32r', 'm68k',
     'mips', 'mipsel', 'powerpc', 'ppc64', 's390', 's390x', 'sh3', 'sh3eb',
     'sh4', 'sh4eb', 'sparc');

# From /usr/share/dpkg/triplettable, included here to make lintian results
# consistent no matter what dpkg one has installed.  This lists all of the
# foo-<cpu> rules.  Note that linux is not present in the current dpkg and
# hence is not present here.
%all_oses = map { $_ => 1 }
    ('kfreebsd', 'knetbsd', 'hurd', 'freebsd', 'openbsd', 'netbsd', 'darwin',
     'solaris');

# Yes, this includes combinations that are rather unlikely to ever exist, like
# hurd-sh3, but the chances of those showing up as errors are rather low and
# this reduces the necessary updating.
#
# armel and lpia are special cases, so handle them separately here.  (They're
# handled separately in /usr/share/dpkg/triplettable.)
%non_standard_archs = map { $_ => 1 }
    grep { !$known_archs{$_} }
        (keys %all_cpus,
         map { my $os = $_; map { "$os-$_" } keys %all_cpus } keys %all_oses),
    ('armel', 'lpia');


%known_sections = map { $_ => 1 }
    ('admin', 'comm', 'devel', 'doc', 'editors', 'electronics',
     'embedded', 'games', 'gnome', 'graphics', 'hamradio', 'interpreters',
     'kde', 'libdevel', 'libs', 'mail', 'math', 'misc', 'net', 'news',
     'oldlibs', 'otherosfs', 'perl', 'python', 'science', 'shells',
     'sound', 'tex', 'text', 'utils', 'web', 'x11'
    );

%known_non_us_parts = map { $_ => 1 } ('non-free', 'contrib', 'main' );

%known_archive_parts = map { $_ => 1 }
    ('non-free', 'contrib', 'non-US', 'non-us' );

%known_prios = map { $_ => 1 }
    ('required', 'important', 'standard', 'optional', 'extra');

# The Ubuntu original-maintainer field is handled separately.
%known_source_fields = map { $_ => 1 }
    ('source', 'version', 'maintainer', 'binary', 'architecture',
     'standards-version', 'files', 'build-depends', 'build-depends-indep',
     'build-conflicts', 'build-conflicts-indep', 'format', 'origin',
     'uploaders', 'python-version', 'autobuild', 'homepage', 'vcs-arch',
     'vcs-bzr', 'vcs-cvs', 'vcs-darcs', 'vcs-git', 'vcs-hg', 'vcs-mtn',
     'vcs-svn', 'vcs-browser', 'dm-upload-allowed', 'bugs', 'checksums-sha1',
     'checksums-sha256', 'checksums-md5');

# The Ubuntu original-maintainer field is handled separately.
%known_binary_fields = map { $_ => 1 }
    ('package', 'version', 'architecture', 'depends', 'pre-depends',
     'recommends', 'suggests', 'enhances', 'conflicts', 'provides',
     'replaces', 'breaks', 'essential', 'maintainer', 'section', 'priority',
     'source', 'description', 'installed-size', 'python-version', 'homepage',
     'bugs', 'origin');

# The Ubuntu original-maintainer field is handled separately.
%known_udeb_fields = map { $_ => 1 }
    ('package', 'version', 'architecture', 'subarchitecture', 'depends',
     'recommends', 'enhances', 'provides', 'replaces', 'breaks', 'replaces',
     'maintainer', 'section', 'priority', 'source', 'description',
     'installed-size', 'kernel-version', 'installer-menu-item', 'bugs',
     'origin');

%known_obsolete_fields = map { $_ => 1 }
    ('revision', 'package-revision', 'package_revision',
     'recommended', 'optional', 'class');

%known_essential = map { $_ => 1 }
    ('base-files', 'base-passwd', 'bash', 'bsdutils', 'coreutils',
     'debianutils', 'diff', 'dpkg', 'e2fsprogs', 'findutils', 'grep', 'gzip',
     'hostname', 'login', 'mktemp', 'mount', 'ncurses-base', 'ncurses-bin',
     'perl-base', 'sed', 'sysvinit', 'sysvinit-utils', 'tar', 'util-linux');

%known_build_essential = map { $_ => 1 }
    ('libc6-dev', 'libc-dev', 'gcc', 'g++', 'make', 'dpkg-dev');

%known_obsolete_packages = map { $_ => 1 }
    ('libstdc++2.8', 'ncurses3.4', 'slang0.99.38', 'newt0.25', 'mesag2',
     'libjpegg6a', 'gmp2', 'libgtop0', 'libghttp0', 'libpgsql', 'tk4.2',
     'tcl7.6', 'libpng0g', 'xbase', 'xlibs-dev', 'debmake', 'gcc-2.95');

# Still in the archive but shouldn't be the primary Emacs dependency.
%known_obsolete_emacs = map { $_ => 1 }
    ('emacs21');

# Used only (at least lintian 1.23.1) for giving a warning about a
# virtual-only dependency
%known_virtual_packages = map { $_ => 1 }
    ('x-terminal-emulator', 'x-window-manager', 'xserver', 'awk', 'c-compiler',
     'c-shell', 'dotfile-module', 'emacsen', 'fortran77-compiler',
     'ftp-server', 'httpd', 'ident-server', 'info-browser',
     'ispell-dictionary', 'kernel-headers', 'kernel-image', 'kernel-source',
     'linux-kernel-log-daemon', 'lambdamoo-core', 'lambdamoo-server',
     'libc-dev', 'man-browser', 'pdf-preview', 'pdf-viewer',
     'postscript-preview', 'postscript-viewer',
     'system-log-daemon', 'tclsh', 'telnet-client', 'telnet-server',
     'time-daemon', 'ups-monitor', 'wish', 'wordlist', 'www-browser',
     'imap-client', 'imap-server', 'mail-reader', 'mail-transport-agent',
     'news-reader', 'news-transport-system', 'pop3-server',
     'mp3-encoder', 'mp3-decoder',
     'java-compiler', 'java2-compiler',
     'java-virtual-machine',
     'java1-runtime', 'java2-runtime',
     'dict-client',
     'foomatic-data',
     'audio-mixer', 'x-audio-mixer',
     'debconf-2.0',
     'aspell-dictionary',
     'radius-server',
     'libgl-dev', 'libglu-dev',
     'automaken'
    );

%known_libstdcs = map { $_ => 1 }
    ('libstdc++2.9-glibc2.1', 'libstdc++2.10', 'libstdc++2.10-glibc2.2',
     'libstdc++3', 'libstdc++3.0', 'libstdc++4', 'libstdc++5',
     'libstdc++6', 'lib64stdc++6',
    );

%known_tcls = map { $_ => 1 }
    ( 'tcl74', 'tcl8.0', 'tcl8.2', 'tcl8.3', 'tcl8.4', );

%known_tclxs = map { $_ => 1 }
    ( 'tclx76', 'tclx8.0.4', 'tclx8.2', 'tclx8.3', 'tclx8.4', );

%known_tks = map { $_ => 1 }
    ( 'tk40', 'tk8.0', 'tk8.2', 'tk8.3', 'tk8.4', );

%known_tkxs = map { $_ => 1 }
    ( 'tkx8.2', 'tkx8.3', );

%known_libpngs = map { $_ => 1 }
    ( 'libpng12-0', 'libpng2', 'libpng3', );

%known_x_metapackages = map { $_ => 1 }
    ( 'x-window-system', 'x-window-system-dev', 'x-window-system-core',
      'xorg', 'xorg-dev', );

# Supported documentation formats for doc-base files.
%known_doc_base_formats = map { $_ => 1 }
    ( 'html', 'text', 'pdf', 'postscript', 'info', 'dvi', 'debiandoc-sgml' );

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 ts=4 et shiftround

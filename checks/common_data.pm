#! /usr/bin/perl -w

package common_data;
use base qw(Exporter);
@EXPORT=qw(%known_archs %known_sections %known_non_us_parts %known_archive_parts
           %known_prios %known_source_fields %known_binary_fields %known_udeb_fields
	   %known_obsolete_fields %known_essential %known_build_essential
	   %known_obsolete_packages %known_virtual_packages
	   %known_libstdcs %known_tcls %known_tclxs %known_tks %known_tkxs
	   %known_libpngs
          );

# simple defines for commonly needed data

%known_archs = map { $_ => 1 }
    ('alpha', 'arm', 'hppa', 'hurd-i386', 'i386', 'ia64', 'mips', 'mipsel',
     'm68k', 'powerpc', 's390', 'sh', 'sparc', 'any', 'all');

%known_sections = map { $_ => 1 }
    ('admin', 'base', 'comm', 'devel', 'doc', 'editors', 'electronics',
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

%known_source_fields = map { $_ => 1 }
    ('source', 'version', 'maintainer', 'binary', 'architecture',
     'standards-version', 'files', 'build-depends', 'build-depends-indep',
     'build-conflicts', 'build-conflicts-indep', 'format', 'origin',
     'uploaders', 'bugs' );

%known_binary_fields = map { $_ => 1 }
    ('package', 'version', 'architecture', 'depends', 'pre-depends',
     'recommends', 'suggests', 'enhances', 'conflicts', 'provides',
     'replaces', 'essential', 'maintainer', 'section', 'priority',
     'source', 'description', 'installed-size');

%known_udeb_fields = map { $_ => 1 }
    ('package', 'version', 'architecture', 'subarchitecture', 'depends',
     'recommends', 'enhances', 'provides', 'installer-menu-item',
     'replaces', 'maintainer', 'section', 'priority',
     'source', 'description', 'installed-size');

%known_obsolete_fields = map { $_ => 1 }
    ('revision', 'package-revision', 'package_revision',
     'recommended', 'optional', 'class');

%known_essential = map { $_ => 1 }
    ('base-files', 'base-passwd', 'bash', 'bsdutils', 'coreutils',
     'debianutils', 'diff', 'dpkg', 'e2fsprogs', 'findutils', 'grep', 'gzip',
     'hostname', 'login', 'mount', 'ncurses-base', 'ncurses-bin',
     'perl-base', 'sed', 'sysvinit', 'tar', 'util-linux');

%known_build_essential = map { $_ => 1 }
    ('libc6-dev', 'libc-dev', 'gcc', 'g++', 'make', 'dpkg-dev');

%known_obsolete_packages = map { $_ => 1 }
    ('libstdc++2.8', 'ncurses3.4', 'slang0.99.38', 'newt0.25', 'mesag2',
     'libjpegg6a', 'gmp2', 'libgtop0', 'libghttp0', 'libpgsql', 'tk4.2',
     'tcl7.6', 'libpng0g', 'xbase');

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
    );

%known_libstdcs = map { $_ => 1 }
    ('libstdc++2.9-glibc2.1', 'libstdc++2.10', 'libstdc++2.10-glibc2.2',
     'libstdc++3', 'libstdc++3.0', 'libstdc++4', 'libstdc++5',
    );

%known_tcls = map { $_ => 1 }
    ( 'tcl74', 'tcl8.0', 'tcl8.2', 'tcl8.3', 'tcl8.4', );

%known_tclxs = map { $_ => 1 }
    ( 'tclx76', 'tclx8.0.4', 'tclx8.2', 'tclx8.3', );

%known_tks = map { $_ => 1 }
    ( 'tk40', 'tk8.0', 'tk8.2', 'tk8.3', 'tk8.4', );

%known_tkxs = map { $_ => 1 }
    ( 'tkx8.2', 'tkx8.3', );

%known_libpngs = map { $_ => 1 }
    ( 'libpng12-0', 'libpng2', 'libpng3', );

1;

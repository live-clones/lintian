# files -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz and Richard Braakman
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

package Lintian::files;
use strict;
use warnings;
use autodie;

use File::Basename;

use Lintian::Data;
use Lintian::Output qw(warning);
use Lintian::Tags qw(tag);
use Lintian::Util qw(drain_pipe fail is_string_utf8_encoded open_gz
  signal_number2name);

my $FONT_PACKAGES = Lintian::Data->new('files/fonts', qr/\s++/);
my $TRIPLETS = Lintian::Data->new('files/triplets', qr/\s++/);
my $LOCALE_CODES = Lintian::Data->new('files/locale-codes', qr/\s++/);
my $INCORRECT_LOCALE_CODES
  = Lintian::Data->new('files/incorrect-locale-codes', qr/\s++/);
my $MULTIARCH_DIRS= Lintian::Data->new('common/multiarch-dirs', qr/\s++/,
    sub { return { 'dir' => $_[1], 'match' => qr/\Q$_[1]\E/ } });

# A list of known packaged Javascript libraries
# and the packages providing them
my @jslibraries = (
    [qr,(?i)mochikit\.js(\.gz)?$, => qr'libjs-mochikit'],
    [
        qr,(?i)mootools((\.v|-)[\d\.]+)?
          (-((core(-server)?)|more)(-(yc|jm|nc))?)?\.js(\.gz)?$,xsm
          => qr'libjs-mootools'
    ],
    [qr,(?i)jquery(\.(min|lite|pack))?\.js(\.gz)?$, => qr'libjs-jquery'],
    [qr,(?i)prototype(-[\d\.]+)?\.js(\.gz)?$, => qr'libjs-prototype'],
    [qr,(?i)scriptaculous\.js(\.gz)?$, => qr'libjs-scriptaculous'],
    [qr,(?i)fckeditor\.js(\.gz)?$, => qr'fckeditor'],
    [qr,(?i)ckeditor\.js(\.gz)?$, => qr'ckeditor'],
    [qr,(?i)cropper(\.uncompressed)?\.js(\.gz)?$, => qr'libjs-cropper'],
    [qr,(?i)(yahoo|yui)-(dom-event|min)\.js(\.gz)?$, => qr'libjs-yui'],
    [qr,(?i)jquery\.cookie(\.min)?\.js(\.gz)?$, => qr'libjs-jquery-cookie'],
    [qr,(?i)jquery\.form(\.min)?\.js(\.gz)?$, => qr'libjs-jquery-form'],
    [
        qr,(?i)jquery\.mousewheel(\.min)?\.js(\.gz)?$, =>
          qr'libjs-jquery-mousewheel'
    ],
    [qr,(?i)jquery\.easing(\.min)?\.js(\.gz)?$, => qr'libjs-jquery-easing'],
    [
        qr,(?i)jquery\.event\.drag(\.min)?\.js(\.gz)?$, =>
          qr'libjs-jquery-event-drag'
    ],
    [
        qr,(?i)jquery\.event\.drop(\.min)?\.js(\.gz)?$, =>
          qr'libjs-jquery-event-drop'
    ],
    [qr,(?i)jquery\.fancybox(\.min)?\.js(\.gz)?$, =>qr'libjs-jquery-fancybox'],
    [
        qr,(?i)jquery\.galleriffic(\.min)?\.js(\.gz)?$, =>
          qr'libjs-jquery-galleriffic'
    ],
    [qr,(?i)jquery\.jfeed(\.min)?\.js(\.gz)?$, => qr'libjs-jquery-jfeed'],
    [qr,(?i)jquery\.history(\.min)?\.js(\.gz)?$, => qr'libjs-jquery-history'],
    [qr,(?i)jquery\.jush(\.min)?\.js(\.gz)?$, => qr'libjs-jquery-jush'],
    [qr,(?i)jquery\.meiomask(\.min)?\.js(\.gz)?$, =>qr'libjs-jquery-meiomask'],
    [
        qr,(?i)jquery\.opacityrollover(\.min)?\.js(\.gz)?$, =>
          qr'libjs-jquery-opacityrollover'
    ],
    [qr,(?i)jquery\.tipsy(\.min)?\.js(\.gz)?$, => qr'libjs-jquery-tipsy'],
    [qr,(?i)jquery\.metadata(\.min)?\.js(\.gz)?$, =>qr'libjs-jquery-metadata'],
    [
        qr,(?i)jquery\.tablesorter(\.min)?\.js(\.gz)?$, =>
          qr'libjs-jquery-tablesorter'
    ],
    [
        qr,(?i)jquery\.livequery(\.min)?\.js(\.gz)?$, =>
          qr'libjs-jquery-livequery'
    ],
    [
        qr,(?i)jquery\.treetable(\.min)?\.js(\.gz)?$, =>
          qr'libjs-jquery-treetable'
    ],
    # Disabled due to false positives.  Needs a content check adding to verify
    # that the file being checked is /the/ yahoo.js
    #    [ qr,(?i)yahoo\.js(\.gz)?$, => qr'libjs-yui' ],
    [qr,(?i)jsjac(\.packed)?\.js(\.gz)?$, => qr'libjs-jac'],
    [qr,(?i)jsMath(-fallback-\w+)?\.js(\.gz)?$, => qr'jsmath'],
    [qr,(?i)tiny_mce(_(popup|src))?\.js(\.gz)?$, => qr'tinymce2?'],
    [qr,(?i)dojo\.js(\.uncompressed\.js)?(\.gz)?$, => qr'libjs-dojo-\w+'],
    [qr,(?i)dijit\.js(\.uncompressed\.js)?(\.gz)?$, => qr'libjs-dojo-\w+'],
    [qr,(?i)strophe(\.min)?\.js(\.gz)?$, => qr'libjs-strophe'],
    [qr,(?i)swfobject(?:\.min)?\.js(?:\.gz)?$, => qr'libjs-swfobject'],
    [qr,(?i)underscore(\.min)?\.js(\.gz)?$, => qr'libjs-underscore'],
    # not yet available in unstable:
    #    [ qr,(?i)(htmlarea|Xinha(Loader|Core))\.js$, => qr'xinha' ],
);

# A list of known packaged PEAR modules
# and the packages providing them
my @pearmodules = (
    [qr,(?<!Auth/)HTTP\.php$, => 'php-http'],
    [qr,Auth\.php$, => 'php-auth'],
    [qr,Auth/HTTP\.php$, => 'php-auth-http'],
    [qr,Benchmark/(Timer|Profiler|Iterate)\.php$, => 'php-benchmark'],
    [qr,Cache\.php$, => 'php-cache'],
    [qr,Cache/Lite\.php$, => 'php-cache-lite'],
    [qr,Compat\.php$, => 'php-compat'],
    [qr,Config\.php$, => 'php-config'],
    [qr,CBC\.php$, => 'php-crypt-cbc'],
    [qr,Date\.php$, => 'php-date'],
    [qr,(?<!Container)/DB\.php$, => 'php-db'],
    [qr,(?<!Container)/File\.php$, => 'php-file'],
    [qr,Log\.php$, => 'php-log'],
    [qr,Log/(file|error_log|null|syslog|sql\w*)\.php$, => 'php-log'],
    [qr,Mail\.php$, => 'php-mail'],
    [qr,(?i)mime(Part)?\.php$, => 'php-mail-mime'],
    [qr,mimeDecode\.php$, => 'php-mail-mimedecode'],
    [qr,FTP\.php$, => 'php-net-ftp'],
    [qr,(?<!Container/)IMAP\.php$, => 'php-net-imap'],
    [qr,SMTP\.php$, => 'php-net-smtp'],
    [qr,(?<!FTP/)Socket\.php$, => 'php-net-socket'],
    [qr,IPv4\.php$, => 'php-net-ipv4'],
    [qr,(?<!Container/)LDAP\.php$, => 'php-net-ldap'],
);

# A list of known packaged php (!PEAR) libraries
# and the packages providing them
my @phplibraries = (
    [qr,(?i)adodb\.inc\.php$, => qr'libphp-adodb'],
    [qr,(?i)Smarty(_Compiler)?\.class\.php$, => qr'smarty3?'],
    [qr,(?i)class\.phpmailer(\.(php|inc))+$, => qr'libphp-phpmailer'],
    [qr,(?i)phpsysinfo\.dtd$, => qr'phpsysinfo'],
    [qr,(?i)class\.(Linux|(Open|Net|Free|)BSD)\.inc\.php$, => qr'phpsysinfo'],
    [qr,Auth/(OpenID|Yadis/Yadis)\.php$, => qr'php-openid'],
    [qr,(?i)Snoopy\.class\.(php|inc)$, => qr'libphp-snoopy'],
    [qr,(?i)markdown\.php$, => qr'libmarkdown-php'],
    [qr,(?i)geshi\.php$, => qr'php-geshi'],
    [qr,(?i)(class[.-])?pclzip\.(inc|lib)?\.php$, => qr'libphp-pclzip'],
    [qr,(?i).*layersmenu.*/(lib/)?PHPLIB\.php$, => qr'libphp-phplayersmenu'],
    [qr,(?i)phpSniff\.(class|core)\.php$, => qr'libphp-phpsniff'],
    [qr,(?i)(class\.)?jabber\.php$, => qr'libphp-jabber'],
    [qr,(?i)(class[\.-])?simplepie(\.(php|inc))+$, => qr'libphp-simplepie'],
    [qr,(?i)jpgraph\.php$, => qr'libphp-jpgraph'],
    [qr,(?i)fpdf\.php$, => qr'php-fpdf'],
    [qr,(?i)getid3\.(lib\.)?(\.(php|inc))+$, => qr'php-getid3'],
    [qr,(?i)streams\.php$, => qr'php-gettext'],
    [qr,(?i)rss_parse\.(php|inc)$, => qr'libphp-magpierss'],
    [qr,(?i)unit_tester\.php$, => qr'php-simpletest'],
    [qr,(?i)Sparkline\.php$, => qr'libsparkline-php'],
    [qr,(?i)(?:class\.)?nusoap\.(?:php|inc)$, => qr'libnusoap-php'],
    [qr,(?i)HTMLPurifier\.php$, => qr'php-htmlpurifier'],
    # not yet available in unstable:,
    #    [ qr,(?i)IXR_Library(\.inc|\.php)+$, => qr'libphp-ixr' ],
    #    [ qr,(?i)(class\.)?kses\.php$, => qr'libphp-kses' ],
);

# A list of known non-free flash executables
my @flash_nonfree = (
    qr<(?i)dewplayer(?:-\w+)?\.swf$>,
    qr<(?i)(?:mp3|flv)player\.swf$>,
    # Situation needs to be clarified:
    #    qr,(?i)multipleUpload\.swf$,
    #    qr,(?i)xspf_jukebox\.swf$,
);

my %PATH_DIRECTORIES = map { $_ => 1 } qw(
  bin/ sbin/ usr/bin/ usr/sbin usr/games/ );

# Common files stored in /usr/share/doc/$pkg that aren't sufficient to
# consider the package non-empty.
my $STANDARD_FILES = Lintian::Data->new('files/standard-files');

# Obsolete path
my $OBSOLETE_PATHS = Lintian::Data->new(
    'files/obsolete-paths',
    qr/\s*\->\s*/,
    sub {
        return {
            'newdir' => $_[1],
            'match' => qr/$_[0]/x,
            'olddir' => $_[0],
        };
    });

sub run {
    my ($pkg, $type, $info, $proc) = @_;
    my ($is_python, $is_perl, $has_binary_perl_file);
    my @nonbinary_perl_files_in_lib;
    my %linked_against_libvga;
    my $py_support_nver;
    my @devhelp;
    my @devhelp_links;

    # X11 bitmapped font directories under /usr/share/fonts/X11 in which we've
    # seen files.
    my %x11_font_dirs;

    my $arch_dep_files = 0;
    # Note: $proc->pkg_src never includes the source version.
    my $source_pkg = $proc->pkg_src;
    my $pkg_section = $info->field('section', '');
    my $arch = $info->field('architecture', '');
    my $isma_same = $info->field('multi-arch', '') eq 'same';
    my $ppkg = quotemeta($pkg);

    # find out which files are scripts
    my %script = map {$_ => 1} (sort keys %{$info->scripts});

    # We only want to warn about these once.
    my $warned_debug_name = 0;

    # Check if package is empty
    my $is_dummy = $info->is_pkg_class('any-meta');

    # read data from objdump-info file
    foreach my $file (sort keys %{$info->objdump_info}) {
        my $objdump = $info->objdump_info->{$file};

        if (defined $objdump->{NEEDED}) {
            for my $lib (@{$objdump->{NEEDED}}) {
                $linked_against_libvga{$file} = 1
                  if $lib =~ /^libvga\.so\./;
            }
        }
    }

    if (!$is_dummy) {
        my $is_empty = 1;
        for my $file ($info->sorted_index) {
            # Ignore directories
            unless ($file =~ m,/$,) {
                # Skip if $file is outside /usr/share/doc/$pkg directory
                if ($file !~ m,^usr/share/doc/\Q$pkg\E,) {
                    # - except if it is an lintian override.
                    next
                      if $file =~ m{\A
                            usr/share/lintian/overrides/$ppkg(?:\.gz)?
                         \Z}xsm;
                    $is_empty = 0;
                    last;
                }
                # Skip if /usr/share/doc/$pkg has files in a subdirectory
                if ($file =~ m,^usr/share/doc/\Q$pkg\E/[^/]++/,) {
                    $is_empty = 0;
                    last;
                }
                # Skip /usr/share/doc/$pkg symlinks.
                next if $file eq "usr/share/doc/$pkg";
                # For files directly in /usr/share/doc/$pkg, if the
                # file isn't one of the uninteresting ones, the
                # package isn't empty.
                unless ($STANDARD_FILES->known(basename($file))) {
                    $is_empty = 0;
                    last;
                }
            }
        }
        if ($is_empty) {
            tag 'empty-binary-package' if ($type ne 'udeb');
            tag 'empty-udeb-package' if ($type eq 'udeb');
        }
    }

    # Read package contents...
    foreach my $file ($info->sorted_index) {
        my $owner = $file->owner . '/' . $file->group;
        my $operm = $file->operm;
        my $link = $file->link;

        $arch_dep_files = 1 if $file !~ m,^usr/share/,o && $file ne 'usr/';

        if (exists($PATH_DIRECTORIES{$file->dirname})) {
            tag 'file-name-in-PATH-is-not-ASCII', $file
              if $file->basename !~ m{\A [[:ascii:]]++ \Z}xsm;
        } elsif (!is_string_utf8_encoded($file->name)) {
            tag 'file-name-is-not-valid-UTF-8', $file;
        }

        if ($file->is_hardlink) {
            my $link_target_dir = $link;
            $link_target_dir =~ s,[^/]*$,,;

            # It may look weird to sort the file and link target here,
            # but since it's a hard link, both files are equal and
            # either could be legitimately reported first.  tar will
            # generate different tar files depending on the hashing of
            # the directory, and this sort produces stable lintian
            # output despite that.
            #
            # TODO: actually, policy says 'conffile', not '/etc' ->
            # extend!
            tag 'package-contains-hardlink', join(' -> ', sort ($file, $link))
              if $file =~ m,^etc/,
              or $link =~ m,^etc/,
              or $file !~ m,^\Q$link_target_dir\E[^/]*$,;
        }

        my ($year) = ($file->date =~ /^(\d{4})/);
        if ($year <= 1975) { # value from dak CVS: Dinstall::PastCutOffYear
            tag 'package-contains-ancient-file', $file, $file->date;
        }

        if (
            !(
                   $file->uid < 100
                || $file->uid == 65_534
                || ($file->uid >= 60_000 && $file->uid < 65_000))
            || !(
                   $file->gid < 100
                || $file->gid == 65_534
                || ($file->gid >= 60_000 && $file->gid < 65_000))
          ) {
            tag 'wrong-file-owner-uid-or-gid', $file,
              $file->uid . '/' . $file->gid;
        }

        # *.devhelp and *.devhelp2 files must be accessible from a directory in
        # the devhelp search path: /usr/share/devhelp/books and
        # /usr/share/gtk-doc/html.  We therefore look for any links in one of
        # those directories to another directory.  The presence of such a link
        # blesses any file below that other directory.
        if (defined $link
            and $file =~ m,usr/share/(?:devhelp/books|gtk-doc/html)/,) {
            my $blessed = $link;
            if ($blessed !~ m,^/,) {
                my $base = $file;
                $base =~ s,/+[^/]+$,,;
                while ($blessed =~ s,^\.\./,,) {
                    $base =~ s,/+[^/]+$,,;
                }
                $blessed = "$base/$blessed";
            }
            push(@devhelp_links, $blessed);
        }

        # check for generic obsolete path
        foreach my $obsolete_path ($OBSOLETE_PATHS->all) {
            my $oldpathmatch = $OBSOLETE_PATHS->value($obsolete_path)->{'match'};
            if ($file =~ m{$oldpathmatch}) {
                my $oldpath = $OBSOLETE_PATHS->value($obsolete_path)->{'olddir'};
                my $newpath = $OBSOLETE_PATHS->value($obsolete_path)->{'newdir'};
                tag 'package-install-into-obsolete-dir', "$file : $oldpath -> $newpath";
            }
        }

        # ---------------- /etc
        if ($file =~ m,^etc/,) {
            # ---------------- /etc/cron.daily, etc.
            if ($file
                =~ m,^etc/cron\.(?:daily|hourly|monthly|weekly|d)/[^\.].*[\+\.],
              ) {
                # NB: cron ships ".placeholder" files, which shouldn't be run.
                tag 'run-parts-cron-filename-contains-illegal-chars', $file;
            }
            # ---------------- /etc/cron.d
            elsif ($file =~ m,^etc/cron\.d/[^\.], and $operm != 0644) {
                # NB: cron ships ".placeholder" files in etc/cron.d,
                # which we shouldn't tag.
                tag 'bad-permissions-for-etc-cron.d-script',
                  sprintf('%s %04o != 0644',$file,$operm);
            }
            # ---------------- /etc/emacs.*
            elsif ( $file =~ m,^etc/emacs.*/\S,
                and $file->is_file
                and $operm != 0644) {
                tag 'bad-permissions-for-etc-emacs-script',
                  sprintf('%s %04o != 0644',$file,$operm);
            }
            # ---------------- /etc/gconf/schemas
            elsif ($file =~ m,^etc/gconf/schemas/\S,) {
                tag 'package-installs-into-etc-gconf-schemas', $file;
            }
            # ---------------- /etc/init.d
            elsif ( $file =~ m,^etc/init\.d/\S,
                and $file !~ m,^etc/init\.d/(?:README|skeleton)$,
                and $operm != 0755
                and $file->is_file) {
                tag 'non-standard-file-permissions-for-etc-init.d-script',
                  sprintf('%s %04o != 0755',$file,$operm);
            }
            #----------------- /etc/ld.so.conf.d
            elsif ($file =~ m,^etc/ld\.so\.conf\.d/.+$, and $pkg !~ /^libc/) {
                tag 'package-modifies-ld.so-search-path', $file;
            }
            #----------------- /etc/modprobe.d
            elsif ( $file =~ m,^etc/modprobe\.d/(.+)$,
                and $1 !~ m,\.conf$,
                and not $file->is_dir) {
                tag 'non-conf-file-in-modprobe.d', $file;
            }
            #---------------- /etc/opt
            elsif ($file =~ m,^etc/opt/.,) {
                tag 'dir-or-file-in-etc-opt', $file;
            }
            #----------------- /etc/pam.conf
            elsif ($file =~ m,^etc/pam.conf, and $pkg ne 'libpam-runtime') {
                tag 'config-file-reserved', "$file by libpam-runtime";
            }
            #----------------- /etc/php5/conf.d
            elsif ($file =~ m,^etc/php5/conf.d/.+\.ini$,) {
                if ($file->is_file) {
                    open(my $fd, '<', $info->unpacked($file));
                    while (<$fd>) {
                        next unless (m/^\s*#/);
                        tag 'obsolete-comments-style-in-php-ini', $file;
                        # only warn once per file:
                        last;
                    }
                    close($fd);
                }
            }
            # ---------------- /etc/rc.d && /etc/rc?.d
            elsif ( $type ne 'udeb'
                and $file =~ m,^etc/rc(?:\d|S)?\.d/\S,
                and $pkg !~ /^(?:sysvinit|file-rc)$/) {
                tag 'package-installs-into-etc-rc.d', $file;
            }
            # ---------------- /etc/rc.boot
            elsif ($file =~ m,^etc/rc\.boot/\S,) {
                tag 'package-installs-into-etc-rc.boot', $file;
            }
            # ---------------- /etc/udev/rules.d
            elsif ($file =~ m,^etc/udev/rules\.d/\S,) {
                tag 'udev-rule-in-etc', $file;
            }
        }
        # ---------------- /usr
        elsif ($file =~ m,^usr/,) {
            # ---------------- /usr/share/doc
            if ($file =~ m,^usr/share/doc/\S,) {
                if ($type eq 'udeb') {
                    tag 'udeb-contains-documentation-file', $file;
                } else {
                    # file not owned by root?
                    if ($owner ne 'root/root') {
                        tag 'bad-owner-for-doc-file',
                          "$file $owner != root/root";
                    }

                    # file directly in /usr/share/doc ?
                    if ($file->is_file and $file =~ m,^usr/share/doc/[^/]+$,) {
                        tag 'file-directly-in-usr-share-doc', $file;
                    }

                    # executable in /usr/share/doc ?
                    if (    $file->is_file
                        and $file !~ m,^usr/share/doc/(?:[^/]+/)?examples/,
                        and ($operm & 0111)) {
                        if ($script{$file}) {
                            tag 'script-in-usr-share-doc', $file;
                        } else {
                            tag 'executable-in-usr-share-doc', $file,
                              (sprintf '%04o', $operm);
                        }
                    }

                    # zero byte file in /usr/share/doc/
                    if ($file->size == 0 and $file->is_regular_file) {
                     # Exceptions: examples may contain empty files for various
                     # reasons, Doxygen generates empty *.map files, and Python
                     # uses __init__.py to mark module directories.
                        unless ($file =~ m,^usr/share/doc/(?:[^/]+/)?examples/,
                            or $file =~ m,^usr/share/doc/(?:.+/)?html/.*\.map$,
                            or $file=~ m,^usr/share/doc/(?:.+/)?__init__\.py$,)
                        {
                            tag 'zero-byte-file-in-doc-directory', $file;
                        }
                    }
                    # gzipped zero byte files:
                    # 276 is 255 bytes (maximal length for a filename)
                    # + gzip overhead
                    if (    $file =~ m,.gz$,
                        and $file->size <= 276
                        and $file->is_file
                        and $info->file_info($file) =~ m/gzip compressed/) {
                        my $fd = open_gz($info->unpacked($file));
                        my $f = <$fd>;
                        close($fd);
                        unless (defined $f and length $f) {
                            tag 'zero-byte-file-in-doc-directory', $file;
                        }
                    }

                    # contains an INSTALL file?
                    if ($file =~ m,^usr/share/doc/$ppkg/INSTALL(?:\..+)*$,) {
                        tag 'package-contains-upstream-install-documentation',
                          $file;
                    }

                    # contains a README for another distribution/platform?
                    if (
                        $file =~ m,^usr/share/doc/$ppkg/readme\.
                             (?:apple|aix|atari|be|beos|bsd|bsdi
                               |cygwin|darwin|irix|gentoo|freebsd|mac|macos
                               |macosx|netbsd|openbsd|osf|redhat|sco|sgi
                               |solaris|suse|sun|vms|win32|win9x|windows
                             )(?:\.txt)?(?:\.gz)?$,xi
                      ) {
                        #<<< No tidy (tag name too long)
                        tag 'package-contains-readme-for-other-platform-or-distro',
                          $file;
                        #>>>
                    }

                    # contains a compressed version of objects.inv in
                    # sphinx-generated documentation?
                    if ($file
                        =~ m,^usr/share/doc/$ppkg/(?:[^/]+/)+objects\.inv\.gz$,
                        and $info->file_info($file) =~ m/gzip compressed/) {
                        tag 'compressed-objects.inv', $file;
                    }

                }
            }
            # ---------------- arch-indep pkconfig
            elsif ($file->is_regular_file
                && $file =~ m,^usr/(?:lib|share)/pkgconfig/[^/]+\.pc$,) {
                open(my $fd, '<', $info->unpacked($file));
              LINE:
                while (my $line = <$fd>) {
                    # check if pkgconfig file include path point to
                    # arch specific dir
                    foreach my $multiarch_dir ($MULTIARCH_DIRS->all) {
                        my $regex
                          = $MULTIARCH_DIRS->value($multiarch_dir)->{'match'};
                        if ($line =~ m{$regex}) {
                            tag 'pkg-config-multi-arch-wrong-dir',$file;
                            last LINE;
                        }
                    }
                }
                close($fd);
            }

            #----------------- /usr/X11R6/
            # links to FHS locations are allowed
            elsif ($file =~ m,^usr/X11R6/, and not $file->is_symlink) {
                tag 'package-installs-file-to-usr-x11r6', $file;
            }

            # ---------------- /usr/lib/debug
            elsif ($file =~ m,^usr/lib/debug/\S,) {
                unless ($warned_debug_name) {
                    tag 'debug-package-should-be-named-dbg', $file
                      unless ($pkg =~ /-dbg$/);
                    $warned_debug_name = 1;
                }

                if (   $file->is_file
                    && $file
                    =~ m,^usr/lib/debug/usr/lib/pyshared/(python\d?(?:\.\d+))/(.++)$,o
                  ) {
                    my $correct = "usr/lib/debug/usr/lib/pymodules/$1/$2";
                    tag 'python-debug-in-wrong-location', $file, $correct;
                }
            }

            # ---------------- /usr/lib/sgml
            elsif ($file =~ m,^usr/lib/sgml/\S,) {
                tag 'file-in-usr-lib-sgml', $file;
            }
            # ---------------- perllocal.pod
            elsif ($file =~ m,^usr/lib/perl.*/perllocal.pod$,) {
                tag 'package-installs-perllocal-pod', $file;
            }
            # ---------------- .packlist files
            elsif ($file =~ m,^usr/lib/perl.*/.packlist$,) {
                tag 'package-installs-packlist', $file;
            }elsif ($file =~ m,^usr/lib/perl5/.*\.(?:pl|pm)$,) {
                push @nonbinary_perl_files_in_lib, $file;
            }elsif ($file =~ m,^usr/lib/perl5/.*\.(?:bs|so)$,) {
                $has_binary_perl_file = 1;
            }
           # ---------------- /usr/lib -- needs to go after the other usr/lib/*
            elsif ($file =~ m,^usr/lib/,) {
                if (    $type ne 'udeb'
                    and $file =~ m,\.(?:bmp|gif|jpeg|jpg|png|tiff|xpm|xbm)$,
                    and not defined $link) {
                    tag 'image-file-in-usr-lib', $file;
                }
            }
            # ---------------- /usr/local
            elsif ($file =~ m,^usr/local/\S+,) {
                if ($file->is_dir) {
                    tag 'dir-in-usr-local', $file;
                } else {
                    tag 'file-in-usr-local', $file;
                }
            }
            # ---------------- /usr/share/applications
            elsif (
                $file =~ m,^usr/share/applications/mimeinfo.cache(?:\.gz)?$,) {
                tag 'package-contains-mimeinfo.cache-file', $file;
            }
            # ---------------- /usr/share/man and /usr/X11R6/man
            elsif ($file =~ m,^usr/X11R6/man/\S+,
                or $file =~ m,^usr/share/man/\S+,) {
                if ($type eq 'udeb') {
                    tag 'udeb-contains-documentation-file', $file;
                }
                if ($file->is_dir) {
                    tag 'stray-directory-in-manpage-directory', $file
                      if ($file
                        !~ m,^usr/(?:X11R6|share)/man/(?:[^/]+/)?(?:man\d/)?$,
                      );
                } elsif ($file->is_file and ($operm & 0111)) {
                    tag 'executable-manpage', $file;
                }
            }
            # ---------------- /usr/share/fonts/X11
            elsif ($file =~ m,^usr/share/fonts/X11/([^/]+)/\S+,) {
                my ($dir, $filename) = ($1, $2);
                if ($dir =~ /^(?:PEX|CID|Speedo|cyrillic)$/) {
                    tag 'file-in-discouraged-x11-font-directory', $file;
                } elsif (
                    $dir !~ /^(?:100dpi|75dpi|misc|Type1|encodings|util)$/) {
                    tag 'file-in-unknown-x11-font-directory', $file;
                }
                if ($dir =~ /^(?:100dpi|75dpi|misc)$/) {
                    $x11_font_dirs{$dir}++;
                }
            }
            # ---------------- /usr/share/info
            elsif ($file =~ m,^usr/share/info\S+,) {
                if ($type eq 'udeb') {
                    tag 'udeb-contains-documentation-file', $file;
                }
                if ($file =~ m,^usr/share/info/dir(?:\.old)?(?:\.gz)?$,) {
                    tag 'package-contains-info-dir-file', $file;
                }
            }
            # ---------------- /usr/share/linda/overrides
            elsif ($file =~ m,^usr/share/linda/overrides/\S+,) {
                tag 'package-contains-linda-override', $file;
            }
            # ---------------- /usr/share/mime
            elsif ($file =~ m,^usr/share/mime/[^/]+$,) {
                tag 'package-contains-mime-cache-file', $file;
            }
            # ---------------- /usr/share/vim
            elsif ($file =~ m,^usr/share/vim/vim(?:current|\d{2})/([^/]++),) {
                my $is_vimhelp = $1 eq 'doc' && $pkg =~ m,^vimhelp-\w++$,;
                my $is_vim = $source_pkg =~ m,vim,;
                tag 'vim-addon-within-vim-runtime-path', $file
                  unless $is_vim
                  or $is_vimhelp;
            }
            # ---------------- /usr/share
            elsif ($file =~ m,^usr/share/[^/]+$,) {
                if ($file->is_file) {
                    tag 'file-directly-in-usr-share', $file;
                }
            }
            # ---------------- /usr/bin
            elsif ($file =~ m,^usr/bin/,) {
                if (    $file->is_dir
                    and $file =~ m,^usr/bin/.,
                    and $file !~ m,^usr/bin/(?:X11|mh)/,) {
                    tag 'subdir-in-usr-bin', $file;
                }
            }
            # ---------------- /usr subdirs
            elsif ($type ne 'udeb' and $file =~ m,^usr/[^/]+/$,){ # FSSTND dirs
                if ($file =~ m,^usr/(?:dict|doc|etc|info|man|adm|preserve)/,) {
                    tag 'FSSTND-dir-in-usr', $file;
                }
                # FHS dirs
                elsif (
                    $file !~ m,^usr/(?:X11R6|X386|
                                    bin|games|include|
                                    lib|
                                    local|sbin|share|
                                    src|spool|tmp)/,x
                  ) {
                    if ($file =~ m,^usr/lib(?'libsuffix'64|x?32)/,) {
                        my $libsuffix = $+{libsuffix};
                        # eglibc exception is due to FHS. Other are
                        # transitional, waiting for full
                        # implementation of multi-arch.  Note that we
                        # allow (e.g.) "lib64" packages to still use
                        # these dirs, since their use appears to be by
                        # intention.
                        unless ($source_pkg eq 'eglibc'
                            or $pkg =~ m/^lib$libsuffix/) {
                            tag 'non-multi-arch-lib-dir', $file;
                        }
                    } else {
                        tag 'non-standard-dir-in-usr', $file;
                    }

                }

                # unless $file =~ m,^usr/[^/]+-linuxlibc1/,; was tied
                # into print above...
                # Make an exception for the altdev dirs, which will go
                # away at some point and are not worth moving.
            }
            # ---------------- .desktop files
            # People have placed them everywhere, but nowadays the
            # consensus seems to be to stick to the fd.org standard
            # drafts, which says that .desktop files intended for
            # menus should be placed in $XDG_DATA_DIRS/applications.
            # The default for $XDG_DATA_DIRS is
            # /usr/local/share/:/usr/share/, according to the
            # basedir-spec on fd.org. As distributor, we should only
            # allow /usr/share.
            #
            # KDE hasn't moved its files from /usr/share/applnk, so
            # don't warn about this yet until KDE adopts the new
            # location.
            elsif ($file =~ m,^usr/share/gnome/apps/.*\.desktop$,) {
                tag 'desktop-file-in-wrong-dir', $file;
            }

            # ---------------- non-games-specific data in games subdirectory
            elsif ($file
                =~ m,^usr/share/games/(?:applications|mime|icons|pixmaps)/,
                and not $file->is_dir) {
                tag 'global-data-in-games-directory', $file;
            }
        }
        # ---------------- /var subdirs
        elsif ($type ne 'udeb' and $file =~ m,^var/[^/]+/$,) { # FSSTND dirs
            if ($file =~ m,^var/(?:adm|catman|named|nis|preserve)/,) {
                tag 'FSSTND-dir-in-var', $file;
            }
            # base-files is special
            elsif ($pkg eq 'base-files' && $file =~ m,^var/(?:backups|local)/,)
            {
                # ignore
            }
            # FHS dirs with exception in Debian policy
            elsif (
                $file !~ m{\A var/
                             (?: account|lib|cache|crash|games
                                |lock|log|opt|run|spool|state
                                |tmp|www|yp)/
             }xsm
              ) {

                tag 'non-standard-dir-in-var', $file;
            }
        } elsif ($type ne 'udeb' and $file =~ m,^var/lib/games/.,) {
            tag 'non-standard-dir-in-var', $file;
            # ---------------- /var/lock, /var/run
        } elsif ($type ne 'udeb' and $file =~ m,^var/lock/.,) {
            tag 'dir-or-file-in-var-lock', $file;
        } elsif ($type ne 'udeb' and $file =~ m,^var/run/.,) {
            tag 'dir-or-file-in-var-run', $file;
        } elsif ($type ne 'udeb' and $file =~ m,^run/.,o) {
            tag 'dir-or-file-in-run', $file;
        }
        # ---------------- /var/www
        # Packages are allowed to create /var/www since it's
        # historically been the default document root, but they
        # shouldn't be installing stuff under that directory.
        elsif ($file =~ m,^var/www/\S+,) {
            tag 'dir-or-file-in-var-www', $file;
        }
        # ---------------- /opt
        elsif ($file =~ m,^opt/.,) {
            tag 'dir-or-file-in-opt', $file;
        } elsif ($file =~ m,^hurd/,) {
            next;
        } elsif ($file =~ m,^servers/,) {
            next;
        }
        # -------------- /home
        elsif ($file =~ m,^home/.,) {
            tag 'dir-or-file-in-home', $file;
        } elsif ($file =~ m,^root/.,) {
            tag 'dir-or-file-in-home', $file;
        }
        # ---------------- /tmp, /var/tmp, /usr/tmp
        elsif ($file =~ m,^tmp/., or $file =~ m,^(?:var|usr)/tmp/.,) {
            tag 'dir-or-file-in-tmp', $file;
        }
        # ---------------- /mnt
        elsif ($file =~ m,^mnt/.,) {
            tag 'dir-or-file-in-mnt', $file;
        }
        # ---------------- /bin
        elsif ($file =~ m,^bin/,) {
            if ($file->is_dir and $file =~ m,^bin/.,) {
                tag 'subdir-in-bin', $file;
            }
        }
        # ---------------- /srv
        elsif ($file =~ m,^srv/.,) {
            tag 'dir-or-file-in-srv', $file;
        }
        # build directory
        elsif ($file =~ m,^var/cache/pbuilder/build/.,
            or $file =~ m,^var/lib/sbuild/.,
            or $file =~ m,^var/lib/buildd/.,) {
            unless ($source_pkg eq 'sbuild') {
                tag 'dir-or-file-in-build-tree', $file;
            }
        }
        # ---------------- FHS directory?
        elsif (
                $file =~ m,^[^/]+/$,o
            and $file !~ m{\A (?:
                  bin|boot|dev|etc|home|lib
                 |mnt|opt|root|run|sbin|srv|sys
                 |tmp|usr|var)  /
          }oxsm
          ) {
            # Make an exception for the base-files package here and
            # other similar packages because they install a slew of
            # top-level directories for setting up the base system.
            # (Specifically, /cdrom, /floppy, /initrd, and /proc are
            # not mentioned in the FHS).
            if ($file =~ m,^lib(?'libsuffix'64|x?32)/,) {
                my $libsuffix = $+{libsuffix};
                # see comments for ^usr/lib(?'libsuffix'64|x?32)
                unless ($source_pkg eq 'eglibc'
                    or $pkg =~ m/^lib$libsuffix/) {
                    tag 'non-multi-arch-lib-dir', $file;
                }
            } else {
                unless ($pkg eq 'base-files'
                    or $pkg eq 'hurd'
                    or $pkg eq 'hurd-udeb'
                    or $pkg =~ /^rootskel(?:-bootfloppy)?/) {
                    tag 'non-standard-toplevel-dir', $file;
                }
            }

        }

        # ---------------- compatibility symlinks should not be used
        if (   $file =~ m,^usr/(?:spool|tmp)/,
            or $file =~ m,^usr/(?:doc|bin)/X11/,
            or $file =~ m,^var/adm/,) {
            tag 'use-of-compat-symlink', $file;
        }

        # ---------------- .ali files (Ada Library Information)
        if ($file =~ m,^usr/lib/.*\.ali$, && $operm != 0444) {
            tag 'bad-permissions-for-ali-file', $file;
        }

        # ---------------- any files
        if (not $file->is_dir) {
            unless (
                   $type eq 'udeb'
                or $file =~ m,^usr/(?:bin|dict|doc|games|
                                    include|info|lib(?:x?32|64)?|
                                    man|sbin|share|src|X11R6)/,x
                or $file =~ m,^lib(?:x?32|64)?/(?:modules/|libc5-compat/)?,
                or $file =~ m,^var/(?:games|lib|www|named)/,
                or $file =~ m,^(?:bin|boot|dev|etc|sbin)/,
                # non-FHS, but still usual
                or $file =~ m,^usr/[^/]+-linux[^/]*/,
                or $file =~ m,^usr/iraf/,
                # not allowed, but tested indivudually
                or $file =~ m{\A (?:
                        home|mnt|opt|root|run|srv
                       |(?:(?:usr|var)/)?tmp)|var/www/}xsm
              ) {
                tag 'file-in-unusual-dir', $file;
            }
        }

        if ($file =~ m,^(?:usr/)?lib/([^/]+)/$,o) {
            my $subdir = $1;
            if ($TRIPLETS->known($subdir)) {
                tag 'triplet-dir-and-architecture-mismatch', "$file is for",
                  $TRIPLETS->value($subdir)
                  unless ($arch eq $TRIPLETS->value($subdir));
            }
        }

        # ---------------- .pyc/.pyo (compiled python files)
        #  skip any file installed inside a __pycache__ directory
        #  - we have a separate check for that directory.
        if ($file =~ m,\.py[co]$,o && $file !~ m,/__pycache__/,o) {
            tag 'package-installs-python-bytecode', $file;
        }

        # ---------------- __pycache__ (directory for pyc/pyo files)
        if ($file->is_dir && $file =~ m,/__pycache__/,o){
            tag 'package-installs-python-pycache-dir', $file;
        }

        # ---------------- .egg (python egg files)
        if (
            $file =~ m,\.egg$,o
            && (   $file =~ m,usr/lib/python\d+(?:\.\d+/),o
                || $file =~ m,usr/lib/pyshared,o
                || $file =~ m,usr/share/,o)
          ) {
            tag 'package-installs-python-egg', $file;
        }

        # ---------------- /usr/lib/site-python
        if ($file =~ m,^usr/lib/site-python/\S,) {
            tag 'file-in-usr-lib-site-python', $file;
        }

        # ---------------- pythonX.Y extensions
        if ($file =~ m,^usr/lib/python\d\.\d/\S,
            and not $file =~ m,^usr/lib/python\d\.\d/(?:site|dist)-packages/,){
            # check if it's one of the Python proper packages
            unless (defined $is_python) {
                $is_python = 0;
                $is_python = 1
                  if $source_pkg =~ m/^python(?:\d\.\d)?$/
                  or $source_pkg  =~ m{\A python\d?-
                         (?:stdlib-extensions|profiler|old-doctools) \Z}xsm;
            }
            tag 'third-party-package-in-python-dir', $file
              unless $is_python;
        }
        # ---------------- perl modules
        if ($file =~ m,^usr/(?:share|lib)/perl/\S,) {
            # check if it's the "perl" package itself
            unless (defined $is_perl) {
                $is_perl = 0;
                $is_perl = 1 if $source_pkg eq 'perl';
            }
            tag 'perl-module-in-core-directory', $file
              unless $is_perl;
        }

        # ---------------- perl modules using old libraries
        # we do the same check on perl scripts in checks/scripts
        {
            my $dep = $info->relation('strong');
            if (   $file->is_file
                && $file =~ m,\.pm$,
                && !$dep->implies(
                    'libperl4-corelibs-perl | perl (<< 5.12.3-7)')) {
                open(my $fd, '<', $info->unpacked($file));
                while (<$fd>) {
                    if (
                        m{ (?:do|require)\s+(?:'|") # do/require

                          # Huge list of perl4 modules...
                          (abbrev|assert|bigfloat|bigint|bigrat
                          |cacheout|complete|ctime|dotsh|exceptions
                          |fastcwd|find|finddepth|flush|getcwd|getopt
                          |getopts|hostname|importenv|look|newgetopt
                          |open2|open3|pwd|shellwords|stat|syslog
                          |tainted|termcap|timelocal|validate)
                          # ... so they end with ".pl" rather than ".pm"
                          \.pl(?:'|")
               }xsm
                      ) {
                        tag 'perl-module-uses-perl4-libs-without-dep',
                          "$file:$. ${1}.pl";
                    }
                }
                close($fd);
            }
        }

        # ---------------- license files
        if (
            $file->basename =~ m{ \A
                # Look for commonly used names for license files
                (?: copying | licen[cs]e | l?gpl | bsd | artistic )
                # ... possibly followed by a version
                [v0-9._-]*
                (?:\. .* )? \Z
                }xsmi
            # Ignore some common extensions for source or compiled
            # extension files.  There was at least one file named
            # "license.el".  These are probably license-displaying
            # code, not license files.  Also ignore executable files
            # in general. This means we get false-negatives for
            # licenses files marked executable, but these will trigger
            # a warning about being executable. (See #608866)
            #
            # Another exception is made for .html and .php because
            # preserving working links is more important than saving
            # some bytes, and because a package had a HTML form for
            # licenses called like that.  Another exception is made
            # for various picture formats since those are likely to
            # just be simply pictures.
            #
            # DTD files are excluded at the request of the Mozilla
            # suite maintainers.  Zope products include license files
            # for runtime display.  underXXXlicense.docbook files are
            # from KDE.
            #
            # Ignore extra license files in examples, since various
            # package building software includes example packages with
            # licenses.
            and ($operm & 0111) == 0
            and not $file =~ m{ \. (?:
                  # Common "non-license" file extensions...
                   el|[ch]|py|cc|pl|pm|hi|p_hi|html|php|rb|xpm
                  |png|jpe?g|gif|svg|dtd|ui|pc
               ) \Z}xsm
            and not $file =~ m,^usr/share/zope/Products/.*\.(?:dtml|pt|cpt)$,
            and not $file =~ m,/under\S+License\.docbook$,
            and not $file =~ m,^usr/share/doc/[^/]+/examples/,
            # liblicense has a manpage called license
            and not $file =~ m,^usr/share/man/(?:[^/]+/)?man\d/,o
            # liblicense (again)
            and not $file =~ m,^usr/share/pyshared-data/,o
            and not defined $link
          ) {

            # okay, we cannot rule it out based on file name; but if
            # it is an elf or a static library, we also skip it.  (In
            # case you hadn't guessed; liblicense)
            my $fileinfo = $info->file_info($file);
            tag 'extra-license-file', $file
              unless $fileinfo and ($fileinfo =~ m/^[^,]*\bELF\b/)
              or ($fileinfo =~ m/\bcurrent ar archive\b/);
        }

        # ---------------- .devhelp2? files
        if (
            $file =~ m,\.devhelp2?(?:\.gz)?$,
            # If the file is located in a directory not searched by devhelp, we
            # check later to see if it's in a symlinked directory.
            and not $file =~ m,^usr/share/(?:devhelp/books|gtk-doc/html)/,
            and not $file =~ m,^usr/share/doc/[^/]+/examples/,
          ) {
            push(@devhelp, $file);
        }

        # ---------------- weird file names
        if ($file =~ m,\s+\z,) {
            tag 'file-name-ends-in-whitespace', $file;
        }
        if ($file =~ m,/\*\z,) {
            tag 'star-file', $file;
        }

        # ---------------- misplaced lintian overrides
        if (   $file =~ m,^usr/share/doc/$ppkg/override\.[lL]intian(?:\.gz)?$,
            or $file =~ m,^usr/share/lintian/overrides/$ppkg/.+,) {
            tag 'override-file-in-wrong-location', $file;
        }

        # ---------------- pyshared-data
        if ($file =~ m,^usr/share/python-support/$ppkg\.(?:public|private)$,){
            $py_support_nver = '(>= 0.90)';
        } elsif ($file =~ m,^usr/share/python-support/\S+,o
            && !$py_support_nver){
            $py_support_nver = '';
        }

        # ---------------- python file locations
        #  - The python people kindly provided the following table.
        # good:
        # /usr/lib/python2.5/site-packages/
        # /usr/lib/python2.6/dist-packages/
        # /usr/lib/python2.7/dist-packages/
        # /usr/lib/python3/dist-packages/
        #
        # bad:
        # /usr/lib/python2.5/dist-packages/
        # /usr/lib/python2.6/site-packages/
        # /usr/lib/python2.7/site-packages/
        # /usr/lib/python3.*/*-packages/
        if (
            $file =~ m{\A
                 (usr/lib/debug/)?
                  usr/lib/python (\d+(?:\.\d+)?)/
                        (site|dist)-packages/(.++)
        \Z}oxsm
          ){
            my ($debug, $pyver, $loc, $rest) = ($1, $2, $3, $4);
            my ($pmaj, $pmin) = split(m/\./o, $pyver, 2);
            my @correction = ();
            $pmin = 0 unless (defined $pmin);
            $debug = '' unless (defined $debug);
            next if ($pmaj < 2 or $pmaj > 3); # Not python 2 or 3
            if ($pmaj == 2 and $pmin < 6){
                # 2.4 and 2.5
                if ($loc ne 'site') {
                    @correction = (
                        "${debug}usr/lib/python${pyver}/$loc-packages/$rest",
                        "${debug}usr/lib/python${pyver}/site-packages/$rest"
                    );
                }
            } elsif ($pmaj == 3){
                # python 3. Everything must be in python3/dist-... and
                # not python3.X/<something>
                if ($pyver ne '3' or $loc ne 'dist'){
                    # bad mojo
                    @correction = (
                        "${debug}usr/lib/python${pyver}/$loc-packages/$rest",
                        "${debug}usr/lib/python3/dist-packages/$rest"
                    );
                }
            } else {
                # python 2.6+
                if ($loc ne 'dist') {
                    @correction = (
                        "${debug}usr/lib/python${pyver}/$loc-packages/$rest",
                        "${debug}usr/lib/python${pyver}/dist-packages/$rest"
                    );
                }
            }
            tag 'python-module-in-wrong-location', @correction
              if (@correction);
        }

        if ($file =~ m,/icons/[^/]+/(\d+)x(\d+)/(?!animations/).*\.png$,) {
            my ($dwidth, $dheight) = ($1, $2);
            my $path;
            if ($file->is_symlink) {
                $path = $file->link_normalized;
            } else {
                $path = $file->name;
            }
            my $fileinfo = $info->file_info($path);
            if ($fileinfo && $fileinfo =~ m/,\s*(\d+)\s*x\s*(\d+)\s*,/) {
                my ($fwidth, $fheight) = ($1, $2);
                my $width_delta = abs($dwidth - $fwidth);
                my $height_delta = abs($dheight - $fheight);
                tag 'icon-size-and-directory-name-mismatch', $file,
                  $fwidth.'x'.$fheight
                  unless ($width_delta <= 2 && $height_delta <= 2);
            }
        }

        if ($file =~ m,/icons/[^/]+/scalable/.*\.(?:png|xpm)$,) {
            tag 'raster-image-in-scalable-directory', $file;
        }

        # ---------------- plain files
        if ($file->is_file) {
            # ---------------- backup files and autosave files
            if (   $file =~ /~$/
                or $file =~ m,\#[^/]+\#$,
                or $file =~ m,/\.[^/]+\.swp$,) {
                tag 'backup-file-in-package', $file;
            }
            if ($file =~ m,/\.nfs[^/]+$,) {
                tag 'nfs-temporary-file-in-package', $file;
            }

            # ---------------- vcs control files
            if (
                $file =~ m{ \.(?:
                         (?:cvs|git|hg)ignore|arch-inventory
                           |hgtags|hg_archival
                         \.txt)\Z}xsm
              ) {
                tag 'package-contains-vcs-control-file', $file;
            }

            # ---------------- subversion and svk commit message backups
            if ($file =~ m/svn-commit.*\.tmp$/) {
                tag 'svn-commit-file-in-package', $file;
            }
            if ($file =~ m/svk-commit.+\.tmp$/) {
                tag 'svk-commit-file-in-package', $file;
            }

            # ---------------- executables with language extensions
            if (
                $file =~ m{\A
                           (?:usr/)?(?:s?bin|games)/[^/]+\.
                           (?:pl|sh|py|php|rb|tcl|bsh|csh|tcl)
                         \Z}xsm
              ) {
                tag 'script-with-language-extension', $file;
            }

            # ---------------- Devel files for Windows
            if (    $file =~ m,/.+\.(?:vcproj|sln|dsp|dsw)(?:\.gz)?$,
                and $file !~ m,^usr/share/doc/,) {
                tag 'windows-devel-file-in-package', $file;
            }

            # ---------------- Autogenerated databases from other OSes
            if ($file =~ m,/Thumbs\.db(?:\.gz)?$,i) {
                tag 'windows-thumbnail-database-in-package', $file;
            }
            if ($file =~ m,/\.DS_Store(?:\.gz)?$,) {
                tag 'macos-ds-store-file-in-package', $file;
            }
            if ($file =~ m,/\._[^_/][^/]*$, and $file !~ m/\.swp$/) {
                tag 'macos-resource-fork-file-in-package', $file;
            }

            # ---------------- embedded Javascript libraries
            foreach my $jslibrary (@jslibraries) {
                if (    $file =~ m,/$jslibrary->[0],
                    and $pkg !~ m,^$jslibrary->[1]$,) {
                    tag 'embedded-javascript-library', $file;
                }
            }

            # ---------------- embedded Feedparser library
            if ($file =~ m,/feedparser\.py$, and $source_pkg ne 'feedparser') {
                open(my $fd, '<', $info->unpacked($file));
                while (<$fd>) {
                    if (m,Universal feed parser,) {
                        tag 'embedded-feedparser-library', $file;
                        last;
                    }
                }
                close($fd);
            }

            # ---------------- embedded PEAR modules
            foreach my $pearmodule (@pearmodules) {
                if ($file =~ m,/$pearmodule->[0], and $pkg ne $pearmodule->[1])
                {
                    open(my $fd, '<', $info->unpacked($file));
                    while (<$fd>) {
                        if (m,/pear[/.],i) {
                            tag 'embedded-pear-module', $file;
                            last;
                        }
                    }
                    close($fd);
                }
            }

            # ---------------- embedded php libraries
            foreach my $phplibrary (@phplibraries) {
                if (    $file =~ m,/$phplibrary->[0],
                    and $pkg !~ m,^$phplibrary->[1]$,) {
                    tag 'embedded-php-library', $file;
                }
            }

            # ---------------- fonts
            if ($file =~ m,/([\w-]+\.(?:[to]tf|pfb))$,i) {
                my $font = lc $1;
                if ($FONT_PACKAGES->known($font)) {
                    tag 'duplicate-font-file', "$file also in",
                      $FONT_PACKAGES->value($font)
                      if (  $pkg ne $FONT_PACKAGES->value($font)
                        and $type ne 'udeb');
                } elsif ($pkg !~ m/^(?:[ot]tf|t1|x?fonts)-/) {
                    tag 'font-in-non-font-package', $file;
                }
                my $finfo = $info->file_info($file) || '';
                if ($finfo =~ m/PostScript Type 1 font program data/) {
                    my $path = $info->unpacked($file);
                    my $foundadobeline = 0;
                    open(my $t1pipe, '-|', 't1disasm', $path);
                    while (my $line = <$t1pipe>) {
                        if ($foundadobeline) {
                            if (
                                $line =~ m{\A [%\s]*
                                   All\s*Rights\s*Reserved\.?\s*
                                       \Z}xsmi
                              ) {
                                #<<< No perltidy - tag name too long
                                tag 'license-problem-font-adobe-copyrighted-fragment',
                                  $file;
                                #>>>
                                last;
                            } else {
                                $foundadobeline = 0;
                            }
                        }
                        if (
                            $line =~ m{\A
                               [%\s]*Copyright\s*\(c\) \s*
                               19\d{2}[\-\s]19\d{2}\s*
                               Adobe\s*Systems\s*Incorporated\.?\s*\Z}xsmi
                          ) {
                            $foundadobeline = 1;
                        }
                        # If copy pasted from black book they are
                        # copyright adobe a few line before the only
                        # place where the startlock is documented is
                        # in the black book copyrighted fragment
                        if ($line =~ m/startlock\s*get\s*exec/) {
                            #<<< no perltidy - tag name too long
                            tag 'license-problem-font-adobe-copyrighted-fragment-no-credit',
                              $file;
                            #>>>
                            last;
                        }
                    }
                    drain_pipe($t1pipe);
                    eval {close($t1pipe);};
                    if (my $err = $@) {
                        # check if we hit #724571 (t1disasm
                        # seg. faults on files).
                        my $exit_code_raw = $?;
                        fail("closing t1disasm $file: $!") if $err->errno;
                        my $code = ($exit_code_raw >> 8) & 0xff;
                        my $sig = $exit_code_raw & 0xff;
                        fail("t1disasm $file exited $code") if $code;
                        if ($sig) {
                            my $signame = signal_number2name($sig);
                            fail("t1disasm $file killed with signal $signame")
                              unless $signame eq 'SEGV'
                              or $signame eq 'BUS';
                            # This is #724571.  The problem is that it
                            # causes the FTP masters to Lintian
                            # auto-reject to trigger (and lintian.d.o
                            # to re-check packages daily if the have a
                            # file triggering this).
                            # Technically, t1disasm has only triggered
                            # a SEGV so far, but it we assume it can
                            # also get hit by a BUS.
                            warning(
                                join(q{ },
                                    "t1disasm $file died with a",
                                    'segmentation fault or bus error'),
                                'This may hide a license-problem warning.'
                            );
                        } else {
                            fail(
                                join(q{ },
                                    "t1disasm $file died with raw",
                                    "exit code $exit_code_raw"));
                        }
                    }
                }
            }

            # ---------------- non-free .swf files
            unless ($info->is_non_free) {
                foreach my $flash (@flash_nonfree) {
                    if ($file =~ m,/$flash,) {
                        tag 'non-free-flash', $file;
                    }
                }
            }

            # ---------------- .gz files
            if ($file =~ m/\.gz$/) {
                my $finfo = $info->file_info($file) || '';
                if ($finfo !~ m/gzip compressed/) {
                    tag 'gz-file-not-gzip', $file;
                } elsif ($isma_same && $file !~ m/\Q$arch\E/o) {
                    my $path = $info->unpacked($file);
                    my $buff;
                    open(my $fd, '<', $path);
                    # We need to read at least 8 bytes
                    if (sysread($fd, $buff, 1024) >= 8) {
                        # Extract the flags and the mtime.
                        #  NN NN  NN NN, NN NN NN NN  - bytes read
                        #  __ __  __ __,    $mtime    - variables
                        my (undef, $mtime) = unpack('NN', $buff);
                        if ($mtime){
                            tag 'gzip-file-is-not-multi-arch-same-safe',$file;
                        }
                    } else {
                        fail "reading $file: $!";
                    }
                    close($fd);
                }
            }

            # --------------- compressed + uncompressed files
            if ($file =~ m,^(.+)\.(?:gz|bz2)$,) {
                tag 'duplicated-compressed-file', $file
                  if $info->file_info($1);
            }

            # ---------------- general: setuid/setgid files!
            if ($operm & 06000) {
                my ($setuid, $setgid) = ('','');
                # get more info:
                $setuid = $file->owner if $operm & 04000;
                $setgid = $file->group if $operm & 02000;

                # 1st special case: program is using svgalib:
                if (exists $linked_against_libvga{$file}) {
                    # setuid root is ok, so remove it
                    if ($setuid eq 'root') {
                        undef $setuid;
                    }
                }

                # 2nd special case: program is a setgid game
                if (   $file =~ m,^usr/lib/games/\S+,
                    or $file =~ m,^usr/games/\S+,) {
                    # setgid games is ok, so remove it
                    if ($setgid eq 'games') {
                        undef $setgid;
                    }
                }

                # 3rd special case: allow anything with suid in the name
                if ($pkg =~ m,-suid,) {
                    undef $setuid;
                }

                # Check for setuid and setgid that isn't expected.
                if ($setuid and $setgid) {
                    tag 'setuid-gid-binary', $file,
                      sprintf('%04o %s',$operm,$owner);
                } elsif ($setuid) {
                    tag 'setuid-binary', $file,
                      sprintf('%04o %s',$operm,$owner);
                } elsif ($setgid) {
                    tag 'setgid-binary', $file,
                      sprintf('%04o %s',$operm,$owner);
                }

                # Check for permission problems other than the setuid status.
                if (($operm & 0444) != 0444) {
                    tag 'executable-is-not-world-readable', $file,
                      sprintf('%04o',$operm);
                } elsif ($operm != 04755
                    && $operm != 02755
                    && $operm != 06755
                    && $operm != 04754) {
                    tag 'non-standard-setuid-executable-perm', $file,
                      sprintf('%04o',$operm);
                }
            }
            # ---------------- general: executable files
            elsif ($operm & 0111) {
                # executable
                if ($owner eq 'root/games') {
                    if ($operm != 2755) {
                        tag 'non-standard-game-executable-perm', $file,
                          sprintf('%04o != 2755',$operm);
                    }
                } else {
                    if (($operm & 0444) != 0444) {
                        tag 'executable-is-not-world-readable', $file,
                          sprintf('%04o',$operm);
                    } elsif ($operm != 0755) {
                        tag 'non-standard-executable-perm', $file,
                          sprintf('%04o != 0755',$operm);
                    }
                }
            }
            # ---------------- general: normal (non-executable) files
            else {
                # not executable
                # special case first: game data
                if (    $operm == 0664
                    and $owner eq 'root/games'
                    and $file =~ m,^var/(lib/)?games/\S+,) {
                    # everything is ok
                } elsif ($operm == 0444 and $file =~ m,^usr/lib/.*\.ali$,) {
                    # Ada library information files should be read-only
                    # since GNAT behaviour depends on that
                    # everything is ok
                } elsif ($operm == 0600 and $file =~ m,^etc/backup.d/,) {
                    # backupninja expects configurations files to be 0600
                } elsif ($file =~ m,^etc/sudoers.d/,) {
                    # sudo requires sudoers files to be mode 0440
                    tag 'bad-perm-for-file-in-etc-sudoers.d', $file,
                      sprintf('%04o != 0440', $operm)
                      unless $operm == 0440;
                } elsif ($operm != 0644) {
                    tag 'non-standard-file-perm', $file,
                      sprintf('%04o != 0644',$operm);
                }
            }
        }
        # ---------------- directories
        elsif ($file->is_dir) {
            # special cases first:
            # game directory with setgid bit
            if (    $file =~ m,^var/(?:lib/)?games/\S+,
                and $operm == 02775
                and $owner eq 'root/games') {
                # do nothing, this is allowed, but not mandatory
            } elsif ((
                       $file eq 'tmp/'
                    or $file eq 'var/tmp/'
                    or $file eq 'var/lock/'
                )
                and $operm == 01777
                and $owner eq 'root/root'
              ) {
                # actually shipping files here is warned about elsewhere
            } elsif ($file eq 'usr/src/'
                and $operm == 02775
                and $owner eq 'root/src') {
                # /usr/src as created by base-files is a special exception
            } elsif ($file eq 'var/local/'
                and $operm == 02775
                and $owner eq 'root/staff') {
                # actually shipping files here is warned about elsewhere
            }
            # otherwise, complain if it's not 0755.
            elsif ($operm != 0755) {
                tag 'non-standard-dir-perm', $file,
                  sprintf('%04o != 0755', $operm);
            }
            if ($file =~ m,/CVS/?$,) {
                tag 'package-contains-vcs-control-dir', $file;
            }
            if ($file =~ m,/\.(?:svn|bzr|git|hg)/?$,) {
                tag 'package-contains-vcs-control-dir', $file;
            }
            if (   ($file =~ m,/\.arch-ids/?$,)
                || ($file =~ m,/\{arch\}/?$,)) {
                tag 'package-contains-vcs-control-dir', $file;
            }
            if ($file =~ m,/\.(?:be|ditrack)/?$,) {
                tag 'package-contains-bts-control-dir', $file;
            }
            if ($file =~ m,/\.xvpics/?$,) {
                tag 'package-contains-xvpics-dir', $file;
            }
            if ($file =~ m,usr/share/doc/[^/]+/examples/examples/?$,) {
                tag 'nested-examples-directory', $file;
            }
            if ($file =~ m,^usr/share/locale/([^/]+)/$,) {
                # Without encoding:
                my ($lwccode) = split(/[.@]/, $1);
                # Without country code:
                my ($lcode) = split(/_/, $lwccode);

                # special exception:
                if ($lwccode ne 'l10n') {
                    if ($INCORRECT_LOCALE_CODES->known($lwccode)) {
                        tag 'incorrect-locale-code',
                          "$lwccode ->",
                          $INCORRECT_LOCALE_CODES->value($lwccode);
                    } elsif ($INCORRECT_LOCALE_CODES->known($lcode)) {
                        tag 'incorrect-locale-code',
                          "$lcode ->",
                          $INCORRECT_LOCALE_CODES->value($lcode);
                    } elsif (!$LOCALE_CODES->known($lcode)) {
                        tag 'unknown-locale-code', $lcode;
                    } elsif ($LOCALE_CODES->known($lcode)
                        && defined($LOCALE_CODES->value($lcode))) {
                        # If there's a key-value pair in the codes
                        # list it means the ISO 639-2 code is being
                        # used instead of ISO 639-1's
                        tag 'incorrect-locale-code', "$lcode ->",
                          $LOCALE_CODES->value($lcode);
                    }
                }
            }
        }
        # ---------------- symbolic links
        elsif ($file->is_symlink) {
            # link

            my $mylink = $link;
            if ($mylink =~ s,//+,/,g) {
                tag 'symlink-has-double-slash', "$file $link";
            }
            if ($mylink =~ s,(.)/$,$1,) {
                tag 'symlink-ends-with-slash', "$file $link";
            }

            # determine top-level directory of file
            $file =~ m,^/?([^/]*),;
            my $filetop = $1;

            if ($mylink =~ m,^/([^/]*),) {
                # absolute link, including link to /
                # determine top-level directory of link
                my $linktop = $1;

                if ($type ne 'udeb' and $filetop eq $linktop) {
                   # absolute links within one toplevel directory are _not_ ok!
                    tag 'symlink-should-be-relative', "$file $link";
                }

                # Any other case is already definitely non-recursive
                tag 'symlink-is-self-recursive', "$file $link"
                  if $mylink eq '/';

            } else {
                # relative link, we can assume from here that the link
                # starts nor ends with /

                my @filecomponents = split('/', $file);
                # chop off the name of the symlink
                pop @filecomponents;

                my @linkcomponents = split('/', $mylink);

                # handle `../' at beginning of $link
                my $lastpop = undef;
                my $linkcomponent = undef;
                while ($linkcomponent = shift @linkcomponents) {
                    if ($linkcomponent eq '.') {
                        tag 'symlink-contains-spurious-segments',"$file $link"
                          unless $mylink eq '.';
                        next;
                    }
                    last if $linkcomponent ne '..';
                    if (@filecomponents) {
                        $lastpop = pop @filecomponents;
                    } else {
                        tag 'symlink-has-too-many-up-segments',"$file $link";
                        goto NEXT_LINK;
                    }
                }

                if (!defined $linkcomponent) {
                    # After stripping all starting .. components, nothing left
                    tag 'symlink-is-self-recursive', "$file $link";
                }

                # does the link go up and then down into the same
                # directory?  (lastpop indicates there was a backref
                # at all, no linkcomponent means the symlink doesn't
                # get up anymore)
                if (   defined $lastpop
                    && defined $linkcomponent
                    && $linkcomponent eq $lastpop) {
                    tag 'lengthy-symlink', "$file $link";
                }

                if ($#filecomponents == -1) {
                    # we've reached the root directory
                    if (   ($type ne 'udeb') && (!defined $linkcomponent)
                        || ($filetop ne $linkcomponent)) {
                        # relative link into other toplevel directory.
                        # this hits a relative symbolic link in the root too.
                        tag 'symlink-should-be-absolute', "$file $link";
                    }
                }

                # check additional segments for mistakes like `foo/../bar/'
                foreach (@linkcomponents) {
                    if ($_ eq '..' || $_ eq '.') {
                        tag 'symlink-contains-spurious-segments',"$file $link";
                        last;
                    }
                }
            }
          NEXT_LINK:

            if ($link =~ m,\.(gz|[zZ]|bz|bz2|tgz|zip)\s*$,) {
                # symlink is pointing to a compressed file

                # symlink has correct extension?
                unless ($file =~ m,\.$1\s*$,) {
                    tag 'compressed-symlink-with-wrong-ext', "$file $link";
                }
            }
        }
        # ---------------- special files
        else {
            # special file
            tag 'special-file', $file, sprintf('%04o',$operm);
        }
    }

    if (!$is_dummy && !$arch_dep_files && $arch ne 'all') {
        tag 'package-contains-no-arch-dependent-files'
          unless $type eq 'udeb';
    }

    # python-support check
    if (defined($py_support_nver) && $pkg ne 'python-support'){
        # Okay - package installs something to /usr/share/python-support/
        # $py_support_nver is either the empty string or a version
        # describing what we need.
        #
        # We also skip debug packages since they are okay as long as
        # foo-dbg depends on foo (= $version) and foo has its dependency
        # correct.
        my $dep = $info->relation('depends');
        tag 'missing-dependency-on-python-support',
          "python-support $py_support_nver"
          unless ($pkg =~ m/-dbg$/
            || $dep->implies("python-support $py_support_nver"));
    }

    # Check for section games but nothing in /usr/games.  Check for
    # any binary to save ourselves from game-data false positives:
    my $games = dir_counts($info, 'usr/games/');
    my $other = dir_counts($info, 'bin/') + dir_counts($info, 'usr/bin/');
    if ($pkg_section =~ m,games$, and $games == 0 and $other > 0) {
        tag 'package-section-games-but-contains-no-game';
    }
    if ($pkg_section =~ m,games$, and $games > 0 and $other > 0) {
        tag 'package-section-games-but-has-usr-bin';
    }
    if ($pkg_section !~ m,games$, and $games > 0 and $other == 0) {
        tag 'games-package-should-be-section-games';
    }

    # Warn about empty directories, but ignore empty directories in
    # /var (packages create directories to hold dynamically created
    # data) or /etc (configuration files generated by maintainer
    # scripts).  Also skip base-files, which is a very special case.
    #
    # Empty Perl directories are an ExtUtils::MakeMaker artifact that
    # will be fixed in Perl 5.10, and people can cause more problems
    # by trying to fix it, so just ignore them.
    #
    # python-support needs a directory for each package even it might
    # be empty
    if ($pkg ne 'base-files') {
        foreach my $dir ($info->sorted_index) {
            next if not $dir->is_dir;
            my $dirname = $dir->name;
            next if ($dirname =~ m{^var/} or $dirname =~ m{^etc/});
            if (scalar($dir->children) == 0) {
                if (    $dirname ne 'usr/lib/perl5/'
                    and $dirname ne 'usr/share/perl5/'
                    and $dirname !~ m;^usr/share/python-support/;) {
                    tag 'package-contains-empty-directory', $dirname;
                }
            }
        }
    }

    if (!$has_binary_perl_file && @nonbinary_perl_files_in_lib) {
        foreach my $file (@nonbinary_perl_files_in_lib) {
            tag 'package-installs-nonbinary-perl-in-usr-lib-perl5', $file;
        }
    }

    # Check for .devhelp2? files that aren't symlinked into paths searched by
    # devhelp.
    for my $file (@devhelp) {
        my $found = 0;
        for my $link (@devhelp_links) {
            if ($file =~ m,^\Q$link,) {
                $found = 1;
                last;
            }
        }
        tag 'package-contains-devhelp-file-without-symlink', $file
          unless $found;
    }

  # Check for including multiple different DPIs of fonts in the same X11 bitmap
  # font package.
    if ($x11_font_dirs{'100dpi'} and $x11_font_dirs{'75dpi'}) {
        tag 'package-contains-multiple-dpi-fonts';
    }
    if ($x11_font_dirs{misc} and keys(%x11_font_dirs) > 1) {
        tag 'package-mixes-misc-and-dpi-fonts';
    }

    return;
}

sub dir_counts {
    my ($info, $filename) = @_;
    if (my $file = $info->index($filename)) {
        return scalar($file->children);
    }
    return 0;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

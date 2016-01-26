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

use Lintian::Data;
use Lintian::Output qw(warning);
use Lintian::Tags qw(tag);
use Lintian::Util qw(drain_pipe fail is_string_utf8_encoded open_gz
  signal_number2name strip normalize_pkg_path);
use Lintian::SlidingWindow;

use constant BLOCKSIZE => 16_384;

my $FONT_PACKAGES = Lintian::Data->new('files/fonts', qr/\s++/);
my $TRIPLETS = Lintian::Data->new('files/triplets', qr/\s++/);
my $LOCALE_CODES = Lintian::Data->new('files/locale-codes', qr/\s++/);
my $INCORRECT_LOCALE_CODES
  = Lintian::Data->new('files/incorrect-locale-codes', qr/\s++/);
my $MULTIARCH_DIRS = Lintian::Data->new('common/multiarch-dirs', qr/\s++/);

my $PRIVACY_BREAKER_WEBSITES= Lintian::Data->new(
    'files/privacy-breaker-websites',
    qr/\s*\~\~/o,
    sub {
        my ($regex, $tag, $suggest) = split(/\s*\~\~\s*/, $_[1], 3);
        $tag = defined($tag) ? strip($tag) : '';
        if (length($tag) == 0) {
            $tag = $_[0];
        }
        my %ret = (
            'tag' => $tag,
            'regexp' => qr/$regex/xsm,
        );
        if (defined($suggest)) {
            $ret{'suggest'} = $suggest;
        }
        return \%ret;
    });

my $PRIVACY_BREAKER_FRAGMENTS= Lintian::Data->new(
    'files/privacy-breaker-fragments',
    qr/\s*\~\~/o,
    sub {
        my ($regex, $tag) = split(/\s*\~\~\s*/, $_[1], 2);
        return {
            'keyword' => $_[0],
            'regex' => qr/$regex/xsm,
            'tag' => $tag,
        };
    });

my $PRIVACY_BREAKER_TAG_ATTR= Lintian::Data->new(
    'files/privacy-breaker-tag-attr',
    qr/\s*\~\~\s*/o,
    sub {
        my ($keywords,$regex) = split(/\s*\~\~\s*/, $_[1], 2);
        $regex =~ s/&URL/(?:(?:ht|f)tps?:)?\/\/[^"\r\n]*/g;
        my @keywordlist;
        my @keywordsorraw = split(/\s*\|\|\s*/,$keywords);
        foreach my $keywordor (@keywordsorraw) {
            my @keywordsandraw = split(/\s*&&\s*/,$keywordor);
            push(@keywordlist, \@keywordsandraw);
        }
        return {
            'keywords' => \@keywordlist,
            'regex' => qr/$regex/xsm,
        };
    });

my $PKG_CONFIG_BAD_REGEX
  = Lintian::Data->new('files/pkg-config-bad-regex',qr/~~~~~/,
    sub { return  qr/$_[0]/xsm;});

my $COMPRESS_FILE_EXTENSIONS
  = Lintian::Data->new('files/compressed-file-extensions',
    qr/\s++/,sub { return qr/\Q$_[0]\E/ });

# an OR (|) regex of all compressed extension
my $COMPRESS_FILE_EXTENSIONS_OR_ALL = sub { qr/(:?$_[0])/ }
  ->(
    join('|',
        map {$COMPRESS_FILE_EXTENSIONS->value($_) }
          $COMPRESS_FILE_EXTENSIONS->all));

# see tag duplicated-compressed-file
my $DUPLICATED_COMPRESSED_FILE_REGEX
  = qr/^(.+)\.(?:$COMPRESS_FILE_EXTENSIONS_OR_ALL)$/;

# see tag compressed-symlink-with-wrong-ext
my $COMPRESSED_SYMLINK_POINTING_TO_COMPRESSED_REGEX
  = qr/\.($COMPRESS_FILE_EXTENSIONS_OR_ALL)\s*$/;

# vcs control files
my $VCS_FILES = Lintian::Data->new(
    'files/vcs-control-files',
    qr/\s++/,
    sub {
        my $regexp = $_[0];
        $regexp =~ s/\$[{]COMPRESS_EXT[}]/$COMPRESS_FILE_EXTENSIONS_OR_ALL/g;
        return qr/(?:$regexp)/x;
    });

# an OR (|) regex of all vcs files
my $VCS_FILES_OR_ALL = sub { qr/(?:$_[0])/ }
  ->(join('|', map { $VCS_FILES->value($_) } $VCS_FILES->all));

# A list of known packaged Javascript libraries
# and the packages providing them
sub _load_file_package_list_mapping {
    my ($datafile,$ext,$tagname,$reinside) = @_;
    unless(defined($reinside)) {
        $reinside = undef;
    }
    my $mapping = Lintian::Data->new(
        $datafile,
        qr/\s*\~\~\s*/,
        sub {
            my $pkg = strip($_[0]);
            my $pkg_regexp = qr/^$pkg$/x;
            my $file_regexp = strip($_[1]);
            $file_regexp =~ s/\$EXT/$ext/g;
            return {
                'pkg_re' => $pkg_regexp,
                'pkg' => $pkg,
                'match' => qr/$file_regexp/,
            };
        });
    return {
        'ext_regexp' => qr/$ext/x,
        'mapping' => $mapping,
        'ext' => $ext,
        'tag' => $tagname,
        'reinside' => $reinside,
    };
}

my $JS_EXT
  = '(?:(?i)[-._]?(?:compiled|lite|min|pack(?:ed)?|yc)?\.js(?:\.gz)?)$';
my $PHP_EXT = '(?i)\.(?:php|inc|dtd)$';
my @FILE_PACKAGE_MAPPING = (
    _load_file_package_list_mapping(
        'files/js-libraries',$JS_EXT,'embedded-javascript-library'
    ),
    _load_file_package_list_mapping(
        'files/php-libraries',$PHP_EXT,'embedded-php-library'
    ),
    _load_file_package_list_mapping(
        'files/pear-modules','(?i)\.php$',
        'embedded-pear-module',qr,pear[/.],
    ),
);

sub _detect_embedded_libraries {
    my ($fname, $file, $pkg) = @_;

    # detect only in regular file
    unless($file->is_regular_file) {
        return;
    }

    foreach my $type (@FILE_PACKAGE_MAPPING) {
        my $typere =  $type->{'ext_regexp'};
        if($fname =~ m/$typere/) {
            my $mapping = $type->{'mapping'};
            my $typetag = $type->{'tag'};
            my $reinside = $type->{'reinside'};
          LIBRARY:
            foreach my $library ($mapping->all) {
                my $library_data = $mapping->value($library);
                my $mainre = $library_data->{'pkg_re'};
                my $mainpkg = $library_data->{'pkg'};
                my $filere = $library_data->{'match'};
                unless ($fname =~ m,$filere,) {
                    next LIBRARY;
                }
                unless ($pkg !~ m,$mainre,) {
                    next LIBRARY;
                }
                if(defined($reinside)) {
                    my $foundre = 0;
                    my $fd = $file->open(':raw');

                    my $sfd
                      = Lintian::SlidingWindow->new($fd,sub { $_=lc($_); });

                  READWINDOW:
                    while (my $block = $sfd->readwindow()) {
                        if ($block =~ m{$reinside}) {
                            $foundre = 1;
                            last READWINDOW;
                        }
                    }
                    close($fd);
                    unless($foundre) {
                        next LIBRARY;
                    }
                }
                tag $typetag, $file, 'please use', $mainpkg;
            }
        }
    }
    return;
}

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
        my @sliptline =  split(/\s*\~\~\s*/, $_[1], 2);
        if (scalar(@sliptline) != 2) {
            fail 'Syntax error in files/obsolete-paths', $.;
        }
        my ($newdir, $moreinfo) =  @sliptline;
        return {
            'newdir' => $newdir,
            'moreinfo' => $moreinfo,
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

    # get the last changelog timestamp
    # if for some weird reasons the timestamp does
    # not exist, it will remain 0
    my $changes = $info->changelog;
    my $changelog_timestamp = 0;
    if (defined $changes) {
        my ($entry) = $changes->data;
        if ($entry && $entry->Timestamp) {
            $changelog_timestamp = $entry->Timestamp;
        }
    }

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
            my $fname = $file->name;
            # Ignore directories
            unless ($fname =~ m,/$,) {
                # Skip if $file is outside /usr/share/doc/$pkg directory
                if ($fname !~ m,^usr/share/doc/\Q$pkg\E,) {
                    # - except if it is an lintian override.
                    next
                      if $fname =~ m{\A
                            usr/share/lintian/overrides/$ppkg(?:\.gz)?
                         \Z}xsm;
                    $is_empty = 0;
                    last;
                }
                # Skip if /usr/share/doc/$pkg has files in a subdirectory
                if ($fname =~ m,^usr/share/doc/\Q$pkg\E/[^/]++/,) {
                    $is_empty = 0;
                    last;
                }
                # Skip /usr/share/doc/$pkg symlinks.
                next if $fname eq "usr/share/doc/$pkg";
                # For files directly in /usr/share/doc/$pkg, if the
                # file isn't one of the uninteresting ones, the
                # package isn't empty.
                unless ($STANDARD_FILES->known($file->basename)) {
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
        my $fname = $file->name;
        my $owner = $file->owner . '/' . $file->group;
        my $operm = $file->operm;
        my $link = $file->link;

        $arch_dep_files = 1 if $fname !~ m,^usr/share/,o && $fname ne 'usr/';

        if (exists($PATH_DIRECTORIES{$file->dirname})) {
            tag 'file-name-in-PATH-is-not-ASCII', $file
              if $file->basename !~ m{\A [[:ascii:]]++ \Z}xsm;
        } elsif (!is_string_utf8_encoded($fname)) {
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
            tag 'package-contains-hardlink',join(' -> ', sort($fname, $link))
              if $fname =~ m,^etc/,
              or $link =~ m,^etc/,
              or $fname !~ m,^\Q$link_target_dir\E[^/]*$,;
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
            and $fname =~ m,^usr/share/(?:devhelp/books|gtk-doc/html)/,) {
            my $blessed = $file->link_normalized // '<broken-link>';
            push(@devhelp_links, $blessed);
        }

        # check for generic obsolete path
        foreach my $obsolete_path ($OBSOLETE_PATHS->all) {
            my $obs_data = $OBSOLETE_PATHS->value($obsolete_path);
            my $oldpathmatch = $obs_data->{'match'};
            if ($fname =~ m{$oldpathmatch}) {
                my $oldpath  = $obs_data->{'olddir'};
                my $newpath  = $obs_data->{'newdir'};
                my $moreinfo = $obs_data->{'moreinfo'};
                tag 'package-installs-into-obsolete-dir',
                  "$file : $oldpath -> $newpath (see also $moreinfo)";
            }
        }

        # see #785662
        if($file->is_regular_file) {
            if(index($fname,'oui') > -1 || index($fname,'iab') > -1) {
                if($fname
                    =~ m,/(?:[^/]-)?(?:oui|iab)(?:\.(txt|idx|db))?(?:\.$COMPRESS_FILE_EXTENSIONS_OR_ALL)?\Z,x
                  ) {
                    unless ($source_pkg eq 'ieee-data') {
                        tag 'package-installs-ieee-data', $file;
                    }
                }
            }
        }

        # build directory
        if (   $fname =~ m,^var/cache/pbuilder/build/,
            or $fname =~ m,^var/lib/sbuild/,
            or $fname =~ m,^var/lib/buildd/,
            or $fname =~ m,^build/,
            or $fname =~ m,^tmp/buildd/,) {
            unless ($source_pkg eq 'sbuild' || $source_pkg eq 'pbuilder') {
                tag 'dir-or-file-in-build-tree', $file;
            }
        }
        # ---------------- /etc
        elsif ($fname =~ m,^etc/,) {
            # /etc/apt
            if ($fname =~ m,^etc/apt/,) {
                # -----------------/etc/apt/preferences
                if ($fname =~ m,^etc/apt/preferences(?:$|\.d/),) {
                    unless ($source_pkg eq 'apt') {
                        tag 'package-installs-apt-preferences', $file;
                    }
                }
                # -----------------/etc/apt/sources
                if ($fname =~ m,^etc/apt/sources\.list(?:$|\.d/),) {
                    unless ($source_pkg eq 'apt') {
                        tag 'package-installs-apt-sources', $file;
                    }
                }
            }
            # ---------------- /etc/cron.daily, etc.
            elsif ($fname
                =~ m,^etc/cron\.(?:daily|hourly|monthly|weekly|d)/[^\.].*[\+\.],
              ) {
                # NB: cron ships ".placeholder" files, which shouldn't be run.
                tag 'run-parts-cron-filename-contains-illegal-chars', $file;
            }
            # ---------------- /etc/cron.d
            elsif ($fname =~ m,^etc/cron\.d/[^\.], and $operm != 0644) {
                # NB: cron ships ".placeholder" files in etc/cron.d,
                # which we shouldn't tag.
                tag 'bad-permissions-for-etc-cron.d-script',
                  sprintf('%s %04o != 0644',$file,$operm);
            }
            # ---------------- /etc/emacs.*
            elsif ( $fname =~ m,^etc/emacs.*/\S,
                and $file->is_file
                and $operm != 0644) {
                tag 'bad-permissions-for-etc-emacs-script',
                  sprintf('%s %04o != 0644',$file,$operm);
            }
            # ---------------- /etc/gconf/schemas
            elsif ($fname =~ m,^etc/gconf/schemas/\S,) {
                tag 'package-installs-into-etc-gconf-schemas', $file;
            }
            # ---------------- /etc/init.d
            elsif ( $fname =~ m,^etc/init\.d/\S,
                and $fname !~ m,^etc/init\.d/(?:README|skeleton)$,
                and $operm != 0755
                and $file->is_file) {
                tag 'non-standard-file-permissions-for-etc-init.d-script',
                  sprintf('%s %04o != 0755',$file,$operm);
            }
            #----------------- /etc/ld.so.conf.d
            elsif ($fname =~ m,^etc/ld\.so\.conf\.d/.+$, and $pkg !~ /^libc/){
                tag 'package-modifies-ld.so-search-path', $file;
            }
            #----------------- /etc/modprobe.d
            elsif ( $fname =~ m,^etc/modprobe\.d/(.+)$,
                and $1 !~ m,\.conf$,
                and not $file->is_dir) {
                tag 'non-conf-file-in-modprobe.d', $file;
            }
            #---------------- /etc/opt
            elsif ($fname =~ m,^etc/opt/.,) {
                tag 'dir-or-file-in-etc-opt', $file;
            }
            #----------------- /etc/pam.conf
            elsif ($fname =~ m,^etc/pam.conf, and $pkg ne 'libpam-runtime') {
                tag 'config-file-reserved', "$fname by libpam-runtime";
            }
            #----------------- /etc/php5/conf.d
            elsif ($fname =~ m,^etc/php5/conf.d/.+\.ini$,) {
                if ($file->is_file) {
                    my $fd = $file->open;
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
                and $fname =~ m,^etc/rc(?:\d|S)?\.d/\S,
                and $pkg !~ /^(?:sysvinit|file-rc)$/) {
                tag 'package-installs-into-etc-rc.d', $file;
            }
            # ---------------- /etc/rc.boot
            elsif ($fname =~ m,^etc/rc\.boot/\S,) {
                tag 'package-installs-into-etc-rc.boot', $file;
            }
            # ---------------- /etc/udev/rules.d
            elsif ($fname =~ m,^etc/udev/rules\.d/\S,) {
                tag 'udev-rule-in-etc', $file;
            }
        }
        # ---------------- /usr
        elsif ($fname =~ m,^usr/,) {
            # ---------------- /usr/share/doc
            if ($fname =~ m,^usr/share/doc/\S,) {
                if ($type eq 'udeb') {
                    tag 'udeb-contains-documentation-file', $file;
                } else {
                    # file not owned by root?
                    if ($owner ne 'root/root') {
                        tag 'bad-owner-for-doc-file',
                          "$fname $owner != root/root";
                    }

                    # file directly in /usr/share/doc ?
                    if (    $file->is_file
                        and $fname =~ m,^usr/share/doc/[^/]+$,){
                        tag 'file-directly-in-usr-share-doc', $file;
                    }

                    # executable in /usr/share/doc ?
                    if (    $file->is_file
                        and $fname !~ m,^usr/share/doc/(?:[^/]+/)?examples/,
                        and ($operm & 0111)) {
                        if ($script{$file}) {
                            tag 'script-in-usr-share-doc', $file;
                        } else {
                            tag 'executable-in-usr-share-doc', $file,
                              (sprintf '%04o', $operm);
                        }
                    }

                    # zero byte file in /usr/share/doc/
                    if ($file->is_regular_file and $file->size == 0) {
                     # Exceptions: examples may contain empty files for various
                     # reasons, Doxygen generates empty *.map files, and Python
                     # uses __init__.py to mark module directories.
                        unless (
                               $fname =~ m,^usr/share/doc/(?:[^/]+/)?examples/,
                            or $fname
                            =~ m,^usr/share/doc/(?:.+/)?(?:doxygen|html)/.*\.map$,
                            or $fname
                            =~ m,^usr/share/doc/(?:.+/)?__init__\.py$,){
                            tag 'zero-byte-file-in-doc-directory', $file;
                        }
                    }
                    # gzipped zero byte files:
                    # 276 is 255 bytes (maximal length for a filename)
                    # + gzip overhead
                    if (    $fname =~ m,.gz$,
                        and $file->is_regular_file
                        and $file->size <= 276
                        and $file->file_info =~ m/gzip compressed/) {
                        my $fd = $file->open_gz;
                        my $f = <$fd>;
                        close($fd);
                        unless (defined $f and length $f) {
                            tag 'zero-byte-file-in-doc-directory', $file;
                        }
                    }

                    # contains an INSTALL file?
                    if ($fname =~ m,^usr/share/doc/$ppkg/INSTALL(?:\..+)*$,){
                        tag
                          'package-contains-upstream-install-documentation',
                          $file;
                    }

                    # contains a README for another distribution/platform?
                    if (
                        $fname =~ m,^usr/share/doc/$ppkg/readme\.
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
                    if ($fname
                        =~ m,^usr/share/doc/$ppkg/(?:[^/]+/)+objects\.inv\.gz$,
                        and $file->file_info =~ m/gzip compressed/) {
                        tag 'file-should-not-be-compressed', $file;
                    }

                }
            }
            # ---------------- arch-indep pkgconfig
            elsif ($file->is_regular_file
                && $fname
                =~ m,^usr/(?:lib(/[^/]+)?|share)/pkgconfig/[^/]+\.pc$,) {
                my $pkg_config_arch = $1 // '';
                $pkg_config_arch =~ s,\A/,,ms;

                my $fd = $file->open(':raw');
                my $sfd = Lintian::SlidingWindow->new($fd);
              BLOCK:
                while (my $block = $sfd->readwindow()) {
                    # remove comment line
                    $block =~ s,\#\V*,,gsm;
                    # remove continuation line
                    $block =~ s,\\\n, ,gxsm;
                    # check if pkgconfig file include path point to
                    # arch specific dir
                  MULTI_ARCH_DIR:
                    foreach my $arch ($MULTIARCH_DIRS->all) {
                        my $madir = $MULTIARCH_DIRS->value($arch);
                        if ($pkg_config_arch eq $madir) {
                            next MULTI_ARCH_DIR;
                        }
                        if ($block =~ m{\W\Q$madir\E(\W|$)}xms) {
                            tag 'pkg-config-multi-arch-wrong-dir',$file,
                              'full text contains architecture specific dir',
                              $madir;
                            last MULTI_ARCH_DIR;
                        }
                    }
                  PKG_CONFIG_TABOO:
                    foreach my $taboo ($PKG_CONFIG_BAD_REGEX->all) {
                        my $regex = $PKG_CONFIG_BAD_REGEX->value($taboo);
                        while($block =~ m{$regex}xmsg) {
                            my $extra = $1 // '';
                            $extra =~ s/\s+/ /g;
                            tag 'pkg-config-bad-directive', $file, $extra;
                        }
                    }
                }
                close($fd);
            }

            #----------------- /usr/X11R6/
            # links to FHS locations are allowed
            elsif ($fname =~ m,^usr/X11R6/, and not $file->is_symlink) {
                tag 'package-installs-file-to-usr-x11r6', $file;
            }

            # ---------------- /usr/lib/debug
            elsif ($fname =~ m,^usr/lib/debug/\S,) {
                unless ($warned_debug_name) {
                    tag 'debug-package-should-be-named-dbg', $file
                      unless $info->is_pkg_class('debug');
                    $warned_debug_name = 1;
                }

                if (   $file->is_file
                    && $fname
                    =~ m,^usr/lib/debug/usr/lib/pyshared/(python\d?(?:\.\d+))/(.++)$,o
                  ) {
                    my $correct = "usr/lib/debug/usr/lib/pymodules/$1/$2";
                    tag 'python-debug-in-wrong-location', $file, $correct;
                }
            }

            # ---------------- /usr/lib/sgml
            elsif ($fname =~ m,^usr/lib/sgml/\S,) {
                tag 'file-in-usr-lib-sgml', $file;
            }
            # ---------------- perllocal.pod
            elsif ($fname =~ m,^usr/lib/perl.*/perllocal.pod$,) {
                tag 'package-installs-perllocal-pod', $file;
            }
            # ---------------- .packlist files
            elsif ($fname =~ m,^usr/lib/perl.*/.packlist$,) {
                tag 'package-installs-packlist', $file;
            }elsif ($fname =~ m,^usr/lib/(?:[^/]+/)?perl5/.*\.(?:pl|pm)$,) {
                push @nonbinary_perl_files_in_lib, $file;
            }elsif ($fname =~ m,^usr/lib/(?:[^/]+/)?perl5/.*\.(?:bs|so)$,) {
                $has_binary_perl_file = 1;
            }
           # ---------------- /usr/lib -- needs to go after the other usr/lib/*
            elsif ($fname =~ m,^usr/lib/,) {
                if (    $type ne 'udeb'
                    and $file =~ m,\.(?:bmp|gif|jpeg|jpg|png|tiff|xpm|xbm)$,
                    and not defined $link) {
                    tag 'image-file-in-usr-lib', $file;
                }
            }
            # ---------------- /usr/local
            elsif ($fname =~ m,^usr/local/\S+,) {
                if ($file->is_dir) {
                    tag 'dir-in-usr-local', $file;
                } else {
                    tag 'file-in-usr-local', $file;
                }
            }
            # ---------------- /usr/share/applications
            elsif (
                $fname=~ m,^usr/share/applications/mimeinfo.cache(?:\.gz)?$,){
                tag 'package-contains-mimeinfo.cache-file', $file;
            }
            # ---------------- /usr/share/cmake-*
            elsif ($fname=~ m,^usr/share/cmake-\d+\.\d+/.+,){
                unless ($source_pkg eq 'cmake') {
                    tag 'package-contains-cmake-private-file', $file;
                }
            }
            # ---------------- /usr/share/mime/
            elsif ($fname=~ m,^usr/share/mime/.+,) {
                # ---------------- /usr/share/mime
                if ($fname =~ m,^usr/share/mime/[^/]+$,) {
                    tag 'package-contains-mime-cache-file', $file;
                }elsif ($fname!~ m,^usr/share/mime/packages/,) {
                    tag 'package-contains-mime-file-outside-package-dir',$file;
                }
            }
            # ---------------- /usr/share/man and /usr/X11R6/man
            elsif ($fname =~ m,^usr/X11R6/man/\S+,
                or $fname =~ m,^usr/share/man/\S+,) {
                if ($type eq 'udeb') {
                    tag 'udeb-contains-documentation-file', $file;
                }
                if ($file->is_dir) {
                    tag 'stray-directory-in-manpage-directory', $file
                      if ($fname
                        !~ m,^usr/(?:X11R6|share)/man/(?:[^/]+/)?(?:man\d/)?$,
                      );
                } elsif ($file->is_file and ($operm & 0111)) {
                    tag 'executable-manpage', $file;
                }
            }
            # ---------------- /usr/share/fonts/X11
            elsif ($fname =~ m,^usr/share/fonts/X11/([^/]+)/\S+,) {
                my $dir = $1;
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
            elsif ($fname =~ m,^usr/share/info\S+,) {
                if ($type eq 'udeb') {
                    tag 'udeb-contains-documentation-file', $file;
                }
                if ($fname =~ m,^usr/share/info/dir(?:\.old)?(?:\.gz)?$,) {
                    tag 'package-contains-info-dir-file', $file;
                }
            }
            # ---------------- /usr/share/linda/overrides
            elsif ($fname =~ m,^usr/share/linda/overrides/\S+,) {
                tag 'package-contains-linda-override', $file;
            }
            # ---------------- /usr/share/p11-kit/modules
            elsif (
                   $fname =~ m{^usr/share/p11-kit/modules/.}
                && $fname !~ m{\A usr/share/p11-kit/modules/
                                  [[:alnum:]][[:alnum:]_.-]*\.module\Z
                              }xsm
              ) {
                tag 'incorrect-naming-of-pkcs11-module', $file;
            }
            # ---------------- /usr/share/vim
            elsif ($fname =~ m,^usr/share/vim/vim(?:current|\d{2})/([^/]++),){
                my $is_vimhelp = $1 eq 'doc' && $pkg =~ m,^vimhelp-\w++$,;
                my $is_vim = $source_pkg =~ m,vim,;
                tag 'vim-addon-within-vim-runtime-path', $file
                  unless $is_vim
                  or $is_vimhelp;
            }
            # ---------------- /usr/share
            elsif ($fname =~ m,^usr/share/[^/]+$,) {
                if ($file->is_file) {
                    tag 'file-directly-in-usr-share', $file;
                }
            }
            # ---------------- /usr/bin
            elsif ($fname =~ m,^usr/bin/,) {
                if (    $file->is_dir
                    and $fname =~ m,^usr/bin/.,
                    and $fname !~ m,^usr/bin/(?:X11|mh)/,) {
                    tag 'subdir-in-usr-bin', $file;
                }
                # check old style config script
                elsif ( $file->is_regular_file
                    and $fname =~ m,-config$,
                    and $script{$file}) {
                    # try to find some indication of
                    # config file (read only one block)
                    my $fd = $file->open(':raw');
                    my $sfd = Lintian::SlidingWindow->new($fd);
                    my $block = $sfd->readwindow();
                    # some common stuff found in config file
                    if (
                        $block
                        and (  index($block,'flag')>-1
                            or index($block,'/include/') > -1
                            or index($block,'pkg-config')  > -1)
                      ) {
                        tag 'old-style-config-script',$file;
                        my $multiarch = $info->field('multi-arch', 'no');
                        # could be ok but only if multi-arch: no
                        if($multiarch ne 'no' or $arch eq 'all') {
                            # check multi-arch path
                            foreach my $archs ($MULTIARCH_DIRS->all) {
                                my $madir= $MULTIARCH_DIRS->value($archs);
                                if ($block =~ m{\W\Q$madir\E(\W|$)}xms){
                         # allow files to begin with triplet if it matches arch
                                    if($file->basename =~ m{^\Q$madir\E}xms) {
                                        next;
                                    }
                                    if($arch eq 'all') {
                                         #<<< No perltidy - tag name too long
                                        tag
                                          'old-style-config-script-multiarch-path-arch-all',
                                          $file,
                                          'full text contains architecture specific dir',
                                          $madir;
                                         #>>>
                                    } else {
                                        #<<< No perltidy - tag name too long
                                        tag
                                          'old-style-config-script-multiarch-path',
                                          $file,
                                          'full text contains architecture specific dir',
                                          $madir;
                                        #>>>
                                    }
                                    last;
                                }
                            }
                        }
                    }
                    close($fd);
                }
            }
            # ---------------- /usr subdirs
            elsif ($type ne 'udeb' and $fname =~ m,^usr/[^/]+/$,)
            { # FSSTND dirs
                if ($fname=~ m,^usr/(?:dict|doc|etc|info|man|adm|preserve)/,){
                    tag 'FSSTND-dir-in-usr', $file;
                }
                # FHS dirs
                elsif (
                    $fname !~ m,^usr/(?:X11R6|X386|
                                    bin|games|include|
                                    lib|
                                    local|sbin|share|
                                    src|spool|tmp)/,x
                  ) {
                    if ($fname =~ m,^usr/lib(?'libsuffix'64|x?32)/,) {
                        my $libsuffix = $+{libsuffix};
                        # eglibc exception is due to FHS. Other are
                        # transitional, waiting for full
                        # implementation of multi-arch.  Note that we
                        # allow (e.g.) "lib64" packages to still use
                        # these dirs, since their use appears to be by
                        # intention.
                        unless ($source_pkg =~ m/^e?glibc$/
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
            elsif ($fname =~ m,^usr/share/gnome/apps/.*\.desktop$,) {
                tag 'desktop-file-in-wrong-dir', $file;
            }

            # ---------------- non-games-specific data in games subdirectory
            elsif ($fname
                =~ m,^usr/share/games/(?:applications|mime|icons|pixmaps)/,
                and not $file->is_dir) {
                tag 'global-data-in-games-directory', $file;
            }
        }
        # ---------------- /var subdirs
        elsif ($type ne 'udeb' and $fname =~ m,^var/[^/]+/$,) { # FSSTND dirs
            if ($fname =~ m,^var/(?:adm|catman|named|nis|preserve)/,) {
                tag 'FSSTND-dir-in-var', $file;
            }
            # base-files is special
            elsif ($pkg eq 'base-files'
                && $fname =~ m,^var/(?:backups|local)/,){
                # ignore
            }
            # FHS dirs with exception in Debian policy
            elsif (
                $fname !~ m{\A var/
                             (?: account|lib|cache|crash|games
                                |lock|log|opt|run|spool|state
                                |tmp|www|yp)/
             }xsm
              ) {

                tag 'non-standard-dir-in-var', $file;
            }
        } elsif ($type ne 'udeb' and $fname =~ m,^var/lib/games/.,) {
            tag 'non-standard-dir-in-var', $file;
            # ---------------- /var/lock, /var/run
        } elsif ($type ne 'udeb' and $fname =~ m,^var/lock/.,) {
            tag 'dir-or-file-in-var-lock', $file;
        } elsif ($type ne 'udeb' and $fname =~ m,^var/run/.,) {
            tag 'dir-or-file-in-var-run', $file;
        } elsif ($type ne 'udeb' and $fname =~ m,^run/.,o) {
            tag 'dir-or-file-in-run', $file;
        }
        # ---------------- /var/www
        # Packages are allowed to create /var/www since it's
        # historically been the default document root, but they
        # shouldn't be installing stuff under that directory.
        elsif ($fname =~ m,^var/www/\S+,) {
            tag 'dir-or-file-in-var-www', $file;
        }
        # ---------------- /opt
        elsif ($fname =~ m,^opt/.,) {
            tag 'dir-or-file-in-opt', $file;
        } elsif ($fname =~ m,^hurd/,) {
            next;
        } elsif ($fname =~ m,^servers/,) {
            next;
        }
        # -------------- /home
        elsif ($fname =~ m,^home/.,) {
            tag 'dir-or-file-in-home', $file;
        } elsif ($fname =~ m,^root/.,) {
            tag 'dir-or-file-in-home', $file;
        }
        # ---------------- /tmp, /var/tmp, /usr/tmp
        elsif ($fname =~ m,^tmp/., or $fname =~ m,^(?:var|usr)/tmp/.,) {
            tag 'dir-or-file-in-tmp', $file;
        }
        # ---------------- /mnt
        elsif ($fname =~ m,^mnt/.,) {
            tag 'dir-or-file-in-mnt', $file;
        }
        # ---------------- /bin
        elsif ($fname =~ m,^bin/,) {
            if ($file->is_dir and $fname =~ m,^bin/.,) {
                tag 'subdir-in-bin', $file;
            }
        }
        # ---------------- /srv
        elsif ($fname =~ m,^srv/.,) {
            tag 'dir-or-file-in-srv', $file;
        }
        # ---------------- FHS directory?
        elsif (
                $fname =~ m,^[^/]+/$,o
            and $fname !~ m{\A (?:
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
            if ($fname =~ m,^lib(?'libsuffix'64|x?32)/,) {
                my $libsuffix = $+{libsuffix};
                # see comments for ^usr/lib(?'libsuffix'64|x?32)
                unless ($source_pkg =~ m/^e?glibc$/
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
        if (   $fname =~ m,^usr/(?:spool|tmp)/,
            or $fname =~ m,^usr/(?:doc|bin)/X11/,
            or $fname =~ m,^var/adm/,) {
            tag 'use-of-compat-symlink', $file;
        }

        # ---------------- any files
        if (not $file->is_dir) {
            unless (
                   $type eq 'udeb'
                or $fname =~ m,^usr/(?:bin|dict|doc|games|
                                    include|info|lib(?:x?32|64)?|
                                    man|sbin|share|src|X11R6)/,x
                or $fname =~ m,^lib(?:x?32|64)?/(?:modules/|libc5-compat/)?,
                or $fname =~ m,^var/(?:games|lib|www|named)/,
                or $fname =~ m,^(?:bin|boot|dev|etc|sbin)/,
                # non-FHS, but still usual
                or $fname =~ m,^usr/[^/]+-linux[^/]*/,
                or $fname =~ m,^usr/iraf/,
                # not allowed, but tested individually
                or $fname =~ m{\A (?:
                        build|home|mnt|opt|root|run|srv
                       |(?:(?:usr|var)/)?tmp)|var/www/}xsm
              ) {
                tag 'file-in-unusual-dir', $file;
            }
        }

        if ($fname =~ m,^(?:usr/)?lib/([^/]+)/$,o) {
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
        if ($fname =~ m,\.py[co]$,o && $fname !~ m,/__pycache__/,o) {
            tag 'package-installs-python-bytecode', $file;
        }

        # ---------------- __pycache__ (directory for pyc/pyo files)
        if ($file->is_dir && $fname =~ m,/__pycache__/,o){
            tag 'package-installs-python-pycache-dir', $file;
        }

        # ---------------- .egg (python egg files)
        if (
            $fname =~ m,\.egg$,o
            && (   $fname =~ m,usr/lib/python\d+(?:\.\d+/),o
                || $fname =~ m,usr/lib/pyshared,o
                || $fname =~ m,usr/share/,o)
          ) {
            tag 'package-installs-python-egg', $file;
        }

        # ---------------- /usr/lib/site-python
        if ($fname =~ m,^usr/lib/site-python/\S,) {
            tag 'file-in-usr-lib-site-python', $file;
        }

        # ---------------- pythonX.Y extensions
        if ($fname =~ m,^usr/lib/python\d\.\d/\S,
            and not $fname=~ m,^usr/lib/python\d\.\d/(?:site|dist)-packages/,){
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
        if ($fname =~ m,^usr/(?:share|lib)/perl/\S,) {
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
                && $fname =~ m,\.pm$,
                && !$dep->implies(
                    'libperl4-corelibs-perl | perl (<< 5.12.3-7)')) {
                my $fd = $file->open;
                while (<$fd>) {
                    if (
                        m{ (?:do|require)\s+['"] # do/require

                          # Huge list of perl4 modules...
                          (abbrev|assert|bigfloat|bigint|bigrat
                          |cacheout|complete|ctime|dotsh|exceptions
                          |fastcwd|find|finddepth|flush|getcwd|getopt
                          |getopts|hostname|importenv|look|newgetopt
                          |open2|open3|pwd|shellwords|stat|syslog
                          |tainted|termcap|timelocal|validate)
                          # ... so they end with ".pl" rather than ".pm"
                          \.pl['"]
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
            and not $fname =~ m{ \. (?:
                  # Common "non-license" file extensions...
                   el|[ch]|py|cc|pl|pm|hi|p_hi|html|php|rb|xpm
                  |png|jpe?g|gif|svg|dtd|ui|pc|mk|lisp
               ) \Z}xsm
            and not $fname=~ m,^usr/share/zope/Products/.*\.(?:dtml|pt|cpt)$,
            and not $fname =~ m,/under\S+License\.docbook$,
            and not $fname =~ m,^usr/share/doc/[^/]+/examples/,
            # liblicense has a manpage called license
            and not $fname =~ m,^usr/share/man/(?:[^/]+/)?man\d/,o
            # liblicense (again)
            and not $fname =~ m,^usr/share/pyshared-data/,o
            # Some GNOME/GTK software uses these to show the "license
            # header".
            and not $fname =~ m,
               ^usr/share/(?:gnome/)?help/[^/]+/[^/]+/license\.page$
             ,x
            # base-files (which is required to ship them)
            and not $fname =~ m,^usr/share/common-licenses/[^/]+$,o
            and not defined $link
          ) {

            # okay, we cannot rule it out based on file name; but if
            # it is an elf or a static library, we also skip it.  (In
            # case you hadn't guessed; liblicense)
            my $fileinfo = $file->file_info;
            tag 'extra-license-file', $file
              unless $fileinfo and ($fileinfo =~ m/^[^,]*\bELF\b/)
              or ($fileinfo =~ m/\bcurrent ar archive\b/);
        }

        # ---------------- .devhelp2? files
        if (
            $fname =~ m,\.devhelp2?(?:\.gz)?$,
            # If the file is located in a directory not searched by devhelp, we
            # check later to see if it's in a symlinked directory.
            and not $fname =~ m,^usr/share/(?:devhelp/books|gtk-doc/html)/,
            and not $fname =~ m,^usr/share/doc/[^/]+/examples/,
          ) {
            push(@devhelp, $fname);
        }

        # ---------------- weird file names
        if ($fname =~ m,\s+\z,) {
            tag 'file-name-ends-in-whitespace', $file;
        }
        if ($fname =~ m,/\*\z,) {
            tag 'star-file', $file;
        }

        # ---------------- misplaced lintian overrides
        if (   $fname =~ m,^usr/share/doc/$ppkg/override\.[lL]intian(?:\.gz)?$,
            or $fname =~ m,^usr/share/lintian/overrides/$ppkg/.+,) {
            tag 'override-file-in-wrong-location', $file;
        }

        # doxygen md5sum
        if ($fname =~ m,^usr/share/doc/$ppkg/[^/]+/.+\.md5$,) {
            if ($file->parent_dir->child('doxygen.png')) {
                tag 'useless-autogenerated-doxygen-file', $file;
            }
        }

        # doxygen compressed map
        if (
            $fname =~ m,^usr/share/doc/(?:.+/)?(?:doxygen|html)/
                         .*\.map\.$COMPRESS_FILE_EXTENSIONS_OR_ALL,x
          ) {
            tag 'file-should-not-be-compressed', $file;
        }

        # ---------------- pyshared-data
        if ($fname=~ m,^usr/share/python-support/$ppkg\.(?:public|private)$,){
            $py_support_nver = '(>= 0.90)';
        } elsif ($fname =~ m,^usr/share/python-support/\S+,o
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
            $fname =~ m{\A
                 (usr/lib/debug/)?
                  usr/lib/python (\d+(?:\.\d+)?)/
                        (site|dist)-packages/(.++)
        \Z}oxsm
          ){
            my ($debug, $pyver, $loc, $rest) = ($1, $2, $3, $4);
            my ($pmaj, $pmin) = split(m/\./o, $pyver, 2);
            my @correction;
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

        if ($fname =~ m,/icons/[^/]+/(\d+)x(\d+)/(?!animations/).*\.png$,){
            my ($dwidth, $dheight) = ($1, $2);
            my $path = $file->resolve_path;
            if ($path && $path->file_info =~ m/,\s*(\d+)\s*x\s*(\d+)\s*,/) {
                my ($fwidth, $fheight) = ($1, $2);
                my $width_delta = abs($dwidth - $fwidth);
                my $height_delta = abs($dheight - $fheight);
                tag 'icon-size-and-directory-name-mismatch', $file,
                  $fwidth.'x'.$fheight
                  unless ($width_delta <= 2 && $height_delta <= 2);
            }
        }

        # ---------------- plain files
        if ($file->is_file) {

            if ($fname =~ m,/icons/[^/]+/scalable/.*\.(?:png|xpm)$,) {
                tag 'raster-image-in-scalable-directory', $file;
            }

            # ---------------- backup files and autosave files
            if (   $fname =~ /~$/
                or $fname =~ m,\#[^/]+\#$,
                or $fname =~ m,/\.[^/]+\.swp$,) {
                tag 'backup-file-in-package', $file;
            }
            if ($fname =~ m,/\.nfs[^/]+$,) {
                tag 'nfs-temporary-file-in-package', $file;
            }

            # ---------------- vcs control files
            if ($fname =~ m,$VCS_FILES_OR_ALL,) {
                tag 'package-contains-vcs-control-file', $file;
            }

            # ---------------- subversion and svk commit message backups
            if ($fname =~ m/svn-commit.*\.tmp$/) {
                tag 'svn-commit-file-in-package', $file;
            }
            if ($fname =~ m/svk-commit.+\.tmp$/) {
                tag 'svk-commit-file-in-package', $file;
            }

            # ---------------- executables with language extensions
            if (
                $fname =~ m{\A
                           (?:usr/)?(?:s?bin|games)/[^/]+\.
                           (?:pl|sh|py|php|rb|tcl|bsh|csh|tcl)
                         \Z}xsm
              ) {
                tag 'script-with-language-extension', $file;
            }

            # ---------------- Devel files for Windows
            if (    $fname =~ m,/.+\.(?:vcproj|sln|dsp|dsw)(?:\.gz)?$,
                and $fname !~ m,^usr/share/doc/,) {
                tag 'windows-devel-file-in-package', $file;
            }

            # ---------------- Autogenerated databases from other OSes
            if ($fname =~ m,/Thumbs\.db(?:\.gz)?$,i) {
                tag 'windows-thumbnail-database-in-package', $file;
            }
            if ($fname =~ m,/\.DS_Store(?:\.gz)?$,) {
                tag 'macos-ds-store-file-in-package', $file;
            }
            if ($fname =~ m,/\._[^_/][^/]*$, and $file !~ m/\.swp$/) {
                tag 'macos-resource-fork-file-in-package', $file;
            }

            # ---------------- embedded libraries
            _detect_embedded_libraries($fname, $file, $pkg);

            # ---------------- embedded Feedparser library
            if (    $fname =~ m,/feedparser\.py$,
                and $source_pkg ne 'feedparser'){
                my $fd = $file->open;
                while (<$fd>) {
                    if (m,Universal feed parser,) {
                        tag 'embedded-feedparser-library', $file;
                        last;
                    }
                }
                close($fd);
            }

            # ---------------- html/javascript
            if ($fname =~ m,\.(?:x?html?|js|xht|xml|css)$,i) {
                if(     $source_pkg eq 'josm'
                    and $file->basename eq 'defaultpresets.xml') {
                    # false positive
                } else {
                    detect_privacy_breach($file);
                }
            }
            # ---------------- fonts
            elsif ($fname =~ m,/([\w-]+\.(?:[to]tf|pfb))$,i) {
                my $font = lc $1;
                if (my $font_owner = $FONT_PACKAGES->value($font)) {
                    tag 'duplicate-font-file', "$fname also in", $font_owner
                      if ($pkg ne $font_owner and $type ne 'udeb');
                } elsif ($pkg !~ m/^(?:[ot]tf|t1|x?fonts)-/) {
                    tag 'font-in-non-font-package', $file;
                }
                my $finfo = $file->file_info;
                if ($finfo =~ m/PostScript Type 1 font program data/) {
                    my $path = $file->fs_path;
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
                    if ($fname =~ m,/$flash,) {
                        tag 'non-free-flash', $file;
                    }
                }
            }

            # ---------------- .gz files
            if ($fname =~ m/\.gz$/) {
                my $finfo = $file->file_info;
                if ($finfo !~ m/gzip compressed/) {
                    tag 'gz-file-not-gzip', $file;
                } else {
                    my ($buff, $mtime);
                    my $fd = $file->open;
                    # We need to read at least 8 bytes
                    if (sysread($fd, $buff, 1024) >= 8) {
                        # Extract the flags and the mtime.
                        #  NN NN  NN NN, NN NN NN NN  - bytes read
                        #  __ __  __ __,    $mtime    - variables
                        (undef, $mtime) = unpack('NN', $buff);
                    } else {
                        fail "reading $file: $!";
                    }
                    close($fd);
                    if ($mtime != 0) {
                        if ($isma_same && $file !~ m/\Q$arch\E/o) {
                            tag 'gzip-file-is-not-multi-arch-same-safe',$file;
                        } else {
                            # see https://bugs.debian.org/762105
                            my $diff= $file->timestamp - $changelog_timestamp;
                            if ($diff > 0) {
                                tag 'package-contains-timestamped-gzip',$file;
                            }
                        }
                    }
                }
            }

            # --------------- compressed + uncompressed files
            if ($fname =~ $DUPLICATED_COMPRESSED_FILE_REGEX) {
                tag 'duplicated-compressed-file', $file
                  if $info->index($1);
            }

            # ---------------- general: setuid/setgid files!
            if ($operm & 06000) {
                my ($setuid, $setgid) = ('','');
                # get more info:
                $setuid = $file->owner if $operm & 04000;
                $setgid = $file->group if $operm & 02000;

                # 1st special case: program is using svgalib:
                if (exists $linked_against_libvga{$fname}) {
                    # setuid root is ok, so remove it
                    if ($setuid eq 'root') {
                        undef $setuid;
                    }
                }

                # 2nd special case: program is a setgid game
                if (   $fname =~ m,^usr/lib/games/\S+,
                    or $fname =~ m,^usr/games/\S+,) {
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
                    and $fname =~ m,^var/(lib/)?games/\S+,) {
                    # everything is ok
                } elsif ($fname =~ m,^usr/lib/.*\.ali$,) {
                    # GNAT compiler wants read-only Ada library information.
                    tag 'bad-permissions-for-ali-file', $file
                      if ($operm != 0444);
                } elsif ($operm == 0600 and $fname =~ m,^etc/backup.d/,) {
                    # backupninja expects configurations files to be 0600
                } elsif ($fname =~ m,^etc/sudoers.d/,) {
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
            if ($file->faux) {
                tag 'missing-intermediate-directory', $file;
            }

            # special cases first:
            # game directory with setgid bit
            if (    $fname =~ m,^var/(?:lib/)?games/\S+,
                and $operm == 02775
                and $owner eq 'root/games') {
                # do nothing, this is allowed, but not mandatory
            } elsif ((
                       $fname eq 'tmp/'
                    or $fname eq 'var/tmp/'
                    or $fname eq 'var/lock/'
                )
                and $operm == 01777
                and $owner eq 'root/root'
              ) {
                # actually shipping files here is warned about elsewhere
            } elsif ($fname eq 'usr/src/'
                and $operm == 02775
                and $owner eq 'root/src') {
                # /usr/src as created by base-files is a special exception
            } elsif ($fname eq 'var/local/'
                and $operm == 02775
                and $owner eq 'root/staff') {
                # actually shipping files here is warned about elsewhere
            }
            # otherwise, complain if it's not 0755.
            elsif ($operm != 0755) {
                tag 'non-standard-dir-perm', $file,
                  sprintf('%04o != 0755', $operm);
            }
            if ($fname =~ m,/CVS/?$,) {
                tag 'package-contains-vcs-control-dir', $file;
            }
            if ($fname =~ m,/\.(?:svn|bzr|git|hg)/?$,) {
                tag 'package-contains-vcs-control-dir', $file;
            }
            if (   ($fname =~ m,/\.arch-ids/?$,)
                || ($fname =~ m,/\{arch\}/?$,)) {
                tag 'package-contains-vcs-control-dir', $file;
            }
            if ($fname =~ m,/\.(?:be|ditrack)/?$,) {
                tag 'package-contains-bts-control-dir', $file;
            }
            if ($fname =~ m,/\.xvpics/?$,) {
                tag 'package-contains-xvpics-dir', $file;
            }
            if ($fname =~ m,/\.thumbnails/?$,) {
                tag 'package-contains-thumbnails-dir', $file;
            }
            if ($fname =~ m,usr/share/doc/[^/]+/examples/examples/?$,) {
                tag 'nested-examples-directory', $file;
            }
            if ($fname =~ m,^usr/share/locale/([^/]+)/$,) {
                # Without encoding:
                my ($lwccode) = split(m/[.@]/, $1);
                # Without country code:
                my ($lcode) = split(m/_/, $lwccode);

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
                tag 'symlink-has-double-slash', "$fname $link";
            }
            if ($mylink =~ s,(.)/$,$1,) {
                tag 'symlink-ends-with-slash', "$fname $link";
            }

            # determine top-level directory of file
            $fname =~ m,^/?([^/]*),;
            my $filetop = $1;

            if ($mylink =~ m,^/([^/]*),) {
                # absolute link, including link to /
                # determine top-level directory of link
                my $linktop = $1;

                if ($type ne 'udeb' and $filetop eq $linktop) {
                   # absolute links within one toplevel directory are _not_ ok!
                    tag 'symlink-should-be-relative', "$fname $link";
                }

                # Any other case is already definitely non-recursive
                tag 'symlink-is-self-recursive', "$fname $link"
                  if $mylink eq '/';

            } else {
                # relative link, we can assume from here that the link
                # starts nor ends with /

                my @filecomponents = split('/', $fname);
                # chop off the name of the symlink
                pop @filecomponents;

                my @linkcomponents = split('/', $mylink);

                # handle `../' at beginning of $link
                my ($lastpop, $linkcomponent);
                while ($linkcomponent = shift @linkcomponents) {
                    if ($linkcomponent eq '.') {
                        tag 'symlink-contains-spurious-segments',
                          "$fname $link"
                          unless $mylink eq '.';
                        next;
                    }
                    last if $linkcomponent ne '..';
                    if (@filecomponents) {
                        $lastpop = pop @filecomponents;
                    } else {
                        tag 'symlink-has-too-many-up-segments',"$fname $link";
                        goto NEXT_LINK;
                    }
                }

                if (!defined $linkcomponent) {
                    # After stripping all starting .. components, nothing left
                    tag 'symlink-is-self-recursive', "$fname $link";
                }

                # does the link go up and then down into the same
                # directory?  (lastpop indicates there was a backref
                # at all, no linkcomponent means the symlink doesn't
                # get up anymore)
                if (   defined $lastpop
                    && defined $linkcomponent
                    && $linkcomponent eq $lastpop) {
                    tag 'lengthy-symlink', "$fname $link";
                }

                if ($#filecomponents == -1) {
                    # we've reached the root directory
                    if (   ($type ne 'udeb') && (!defined $linkcomponent)
                        || ($filetop ne $linkcomponent)) {
                        # relative link into other toplevel directory.
                        # this hits a relative symbolic link in the root too.
                        tag 'symlink-should-be-absolute', "$fname $link";
                    }
                }

                # check additional segments for mistakes like `foo/../bar/'
                foreach (@linkcomponents) {
                    if ($_ eq '..' || $_ eq '.') {
                        tag 'symlink-contains-spurious-segments',
                          "$fname $link";
                        last;
                    }
                }
            }
          NEXT_LINK:

            if ($link =~ $COMPRESSED_SYMLINK_POINTING_TO_COMPRESSED_REGEX) {
                # symlink is pointing to a compressed file

                # symlink has correct extension?
                unless ($fname =~ m,\.$1\s*$,) {
                    tag 'compressed-symlink-with-wrong-ext', "$fname $link";
                }
            }
        }
        # ---------------- special files
        else {
            # special file
            tag 'special-file', $fname, sprintf('%04o',$operm);
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
                if (    $dirname !~ m;^usr/lib/(?:[^/]+/)?perl5/$;
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

sub is_localhost {
    my ($urlshort) = @_;
    if(    $urlshort =~ m!^(?:[^/]+@)?localhost(?:[:][^/]+)?/!i
        || $urlshort =~ m!^(?:[^/]+@)?::1(?:[:][^/]+)?/!i
        || $urlshort =~ m!^(?:[^/]+@)?127(?:\.\d{1,3}){3}(?:[:][^/]+)?/!i) {
        return 1;
    }else {
        return 0;
    }
}

sub _check_tag_url_privacy_breach {
    my ($fulltag, $tagattr, $url,$privacybreachhash, $file) = @_;
    my $website = $url;
    # detect also "^//" trick
    $website =~ s,^"?(?:(?:ht|f)tps?:)?//,,;
    $website =~ s/"?$//;

    if (is_localhost($website)){
        # do nothing ok
        return;
    }
    # reparse fulltag for rel
    if ($tagattr eq 'link') {
        my $rel = $fulltag;
        $rel =~ m,<link
                      (?:\s[^>]+)? \s+
                      rel="([^"\r\n]*)"
                      [^>]*
                      >,xismog;
        my $relcontent = $1;
        if (defined($relcontent)) {
            if ($relcontent eq 'schema.dct') {
                # see #736992
                return;
            } elsif  ($relcontent eq 'bookmark') {
                # see #746656
                return;
            } elsif ($relcontent eq 'generator-home') {
                # generator-home is used by texinfo
                return;
                # reparse for alternate (css alternate is loaded)
            } elsif ($relcontent eq 'alternate') {
                my $type = $fulltag;
                $type =~ m,<link
                      (?:\s[^>]+)? \s+
                      type="([^"\r\n]*)"
                      [^>]*
                      >,xismog;
                my $typecontent = $1;
                if($typecontent eq 'application/rdf+xml') {
                    # see #79991
                    return;
                }
            }
        }
    }

    # track well known site
    foreach my $breaker ($PRIVACY_BREAKER_WEBSITES->all) {
        my $value = $PRIVACY_BREAKER_WEBSITES->value($breaker);
        my $regex = $value->{'regexp'};
        if ($website =~ m{$regex}mxs) {
            unless (exists $privacybreachhash->{'tag-'.$breaker}) {
                my $tag =  $value->{'tag'};
                my $suggest = $value->{'suggest'} // '';
                $privacybreachhash->{'tag-'.$breaker}= 1;
                tag $tag, $file, $suggest, "($url)";
            }
            # do not go to generic case
            return;
        }
    }
    # generic case
    unless (exists $privacybreachhash->{'tag-generic-'.$website}){
        tag 'privacy-breach-generic', $file, "($url)";
        $privacybreachhash->{'tag-generic-'.$website} = 1;
    }
    return;
}

# According to html norm src attribute is used by tags:
#
# audio(v5+), embed (v5+), iframe (v4), frame, img, input, script, source, track(v5), video (v5)
# Add other tags with src due to some javascript code:
# div due to div.js
# div data-href due to jquery
# css with @import
sub detect_generic_privacy_breach {
    my ($block, $privacybreachhash, $file) = @_;
    my %matchedkeyword;

    # now check generic tag
  TYPE:
    foreach my $type ($PRIVACY_BREAKER_TAG_ATTR->all) {
        my $keyvalue = $PRIVACY_BREAKER_TAG_ATTR->value($type);
        my $keywords =  $keyvalue->{'keywords'};

        my $orblockok = 0;
      ORBLOCK:
        foreach my $keywordor (@$keywords) {
          ANDBLOCK:
            foreach my $keyword (@$keywordor) {
                my $thiskeyword = $matchedkeyword{$keyword};
                if(!defined($thiskeyword)) {
                    if(index($block,$keyword) > -1) {
                        $matchedkeyword{$keyword} = 1;
                        $orblockok = 1;
                    }else {
                        $matchedkeyword{$keyword} = 0;
                        $orblockok = 0;
                        next ORBLOCK;
                    }
                }
                if($matchedkeyword{$keyword} == 0) {
                    $orblockok = 0;
                    next ORBLOCK;
                }else {
                    $orblockok = 1;
                }
            }
            if($orblockok == 1) {
                last ORBLOCK;
            }
        }
        if($orblockok == 0) {
            next TYPE;
        }
        my $regex = $keyvalue->{'regex'};
        while($block=~m{$regex}g){
            _check_tag_url_privacy_breach($1, $2, $3,$privacybreachhash,$file);
        }
    }
    return;
}

sub detect_privacy_breach {
    my ($file) = @_;
    my %privacybreachhash;

    # detect only in regular file
    unless($file->is_regular_file) {
        return;
    }

    my $fd = $file->open(':raw');

    my $sfd = Lintian::SlidingWindow->new($fd,sub { $_=lc($_); },BLOCKSIZE);

    while (my $block = $sfd->readwindow()) {
        # try generic fragment tagging
        foreach my $keyword ($PRIVACY_BREAKER_FRAGMENTS->all) {
            if(index($block,$keyword) > -1) {
                my $keyvalue = $PRIVACY_BREAKER_FRAGMENTS->value($keyword);
                my $regex = $keyvalue->{'regex'};
                if ($block =~ m{$regex}) {
                    my $breaker_tag = $keyvalue->{'tag'};
                    unless (exists $privacybreachhash{'tag-'.$breaker_tag}){
                        $privacybreachhash{'tag-'.$breaker_tag} = 1;
                        tag $breaker_tag, $file;
                    }
                }
            }
        }
        if(   index($block,'src="http') > -1
            ||index($block,'src="ftp') > -1
            ||index($block,'src="//') > -1
            ||index($block,'data-href="http') > -1
            ||index($block,'data-href="ftp') > -1
            ||index($block,'data-href="//') > -1
            ||index($block,'codebase="http') > -1
            ||index($block,'codebase="ftp') > -1
            ||index($block,'codebase="//') > -1
            ||index($block,'data="http') > -1
            ||index($block,'data="ftp') > -1
            ||index($block,'data="//') > -1
            ||index($block,'poster="http') > -1
            ||index($block,'poster="ftp') > -1
            ||index($block,'poster="//') > -1
            ||index($block,'<link') > -1
            ||index($block,'@import') > -1){
            detect_generic_privacy_breach($block,\%privacybreachhash,$file);
        }
    }
    close($fd);
    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

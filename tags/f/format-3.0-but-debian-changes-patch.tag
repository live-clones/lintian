Tag: format-3.0-but-debian-changes-patch
Severity: warning
Check: debian/patches/quilt
Explanation: This package declares source format 3.0 (quilt), but the Debian
 .debian.tar.gz file contains a debian-changes-VERSION patch, which represents
 direct changes to files outside of the <tt>debian</tt> directory. This often
 indicates accidental changes that weren't meant to be in the package or changes
 that were supposed to be separated out into a patch.
 .
 If this is intentional, you may wish to consider adding
 <tt>single-debian-patch</tt> to <tt>debian/source/options</tt>, and/or a patch
 header to <tt>debian/source/patch-header</tt> explaining why this is done.

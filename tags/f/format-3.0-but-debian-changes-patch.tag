Tag: format-3.0-but-debian-changes-patch
Severity: warning
Check: debian/patches/quilt
Explanation: This package declares source format 3.0 (quilt), but the Debian
 .debian.tar.gz file contains a debian-changes-VERSION patch, which represents
 direct changes to files outside of the <code>debian</code> directory. This often
 indicates accidental changes that weren't meant to be in the package or changes
 that were supposed to be separated out into a patch.
 .
 If this is intentional, you may wish to consider adding
 <code>single-debian-patch</code> to <code>debian/source/options</code>, and/or a patch
 header to <code>debian/source/patch-header</code> explaining why this is done.

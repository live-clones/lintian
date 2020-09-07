Tag: debian-watch-mangles-debian-version-improperly
Severity: info
Check: debian/watch
Renamed-From: debian-watch-file-should-dversionmangle-not-uversionmangle
See-Also: https://wiki.debian.org/DEHS
Explanation: The version of this package contains <code>dfsg</code>, <code>ds</code>,
 or <code>debian</code>, but a misleading upstream version mangling occurs in
 the <code>debian/watch</code> file. Since the <code>dfsg</code> string is not
 part of the upstream version and its addition is Debian-specific, the
 <code>debian/watch</code> file should use the dversionmangle option to
 remove, instead of adding in uversionmangle, the <code>dfsg</code> before
 comparing version numbers.

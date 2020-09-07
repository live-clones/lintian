Tag: debian-watch-not-mangling-version
Severity: warning
Check: debian/watch
Renamed-From: debian-watch-file-should-mangle-version
See-Also: uscan(1), https://wiki.debian.org/DEHS
Explanation: The version of this package contains <code>dfsg</code>, <code>ds</code>,
 or <code>debian</code>, which normally indicates that the upstream source
 has been repackaged to comply with the Debian Free Software Guidelines
 (or similar reason), but there is no version mangling in the
 <code>debian/watch</code> file. Since the <code>dfsg</code> string is not
 part of the upstream version, the <code>debian/watch</code> file should
 use the dversionmangle option to remove the <code>dfsg</code> before
 version number comparison.

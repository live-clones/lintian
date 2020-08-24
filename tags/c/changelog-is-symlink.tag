Tag: changelog-is-symlink
Severity: warning
Check: nmu
Explanation: The file <tt>debian/changelog</tt> is a symlink instead of a regular
 file. This is unnecessary and makes package checking and manipulation
 more difficult. If the changelog should be available in the source
 package under multiple names, make <tt>debian/changelog</tt> the real
 file and the other names symlinks to it.
 .
 This problem may have prevented Lintian from performing other checks,
 leading to undetected changelog errors.

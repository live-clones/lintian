Tag: debian-rules-is-symlink
Severity: warning
Check: debian/rules
Explanation: The file <code>debian/rules</code> is a symlink instead of a regular
 file. This is unnecessary and makes package checking and manipulation
 more difficult. If the rules file should be available in the source
 package under multiple names, make <code>debian/rules</code> the real
 file and the other names symlinks to it.
 .
 This problem may have prevented Lintian from performing other checks,
 leading to undetected changelog errors.

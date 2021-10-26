Tag: maintainer-script-empty
Severity: warning
Check: maintainer-scripts/empty
Explanation: The named maintainer script does not appear to contain code
 other than comments or boilerplate such as <code>set -e</code>,
 <code>exit</code> statements, or a <code>case</code> statement
 to parse options.
 .
 While harmless in most cases, it is not needed. The package may also leave
 files behind until purged, and can contribute to rare problems when
 <code>dpkg</code> fails because no maintainer scripts are present.
 .
 Please do not ship the maintainer script unless it does something useful.

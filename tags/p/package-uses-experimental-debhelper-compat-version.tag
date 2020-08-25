Tag: package-uses-experimental-debhelper-compat-version
Severity: pedantic
Check: debhelper
See-Also: debhelper(7)
Explanation: The debhelper compatibility version used by this package is marked
 as experimental by the debhelper developer. You should consider using a
 stable compatibility version instead.
 .
 The compatibility version can be set by specifying
 <code>debhelper-compat (= 12)</code> in your package's
 <code>Build-Depends</code>, by the legacy <code>debian/compat</code> file or
 even by setting and exporting DH_COMPAT in <code>debian/rules</code>. If it
 is not set in either place, debhelper defaults to the deprecated
 compatibility version 1.

Tag: debug-suffix-not-dbg
Severity: warning
Check: files/debug
Renamed-From: debug-package-should-be-named-dbg
Explanation: This package provides at least one file in <code>/usr/lib/debug</code>,
 which is intended for detached debugging symbols, but the package name
 does not end in "-dbg". Detached debugging symbols should be put into a
 separate package, Priority: extra, with a package name ending in "-dbg".
See-Also: devref 6.7.9

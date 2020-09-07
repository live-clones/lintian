Tag: debhelper-compat-file-is-missing
Severity: warning
Check: debhelper
Explanation: The package build-depends on debhelper but does not ship a compat
 file. Packages not using an experimental or beta compatibility level
 may alternatively Build-Depend on the debhelper-compat virtual package,
 For example:
 .
  Build-Depends: debhelper-compat (= 13)
 .
 Please refer to the debhelper documentation on how to create the
 compat file and the differences between each compat level.
See-Also: https://lists.debian.org/debian-devel-changes/2012/01/msg01335.html,
 debhelper(7)

Tag: debhelper-base-compat-level-is-missing
Severity: warning
Check: debhelper
Renamed-from:
 debhelper-compat-file-is-missing
Explanation: The package build-depends on debhelper but does not ship a compat
 file. Packages not using an experimental or beta compatibility level
 may alternatively Build-Depend on the debhelper-compat virtual package,
 For example:
 .
  Build-Depends: debhelper-compat (= 13)
 .
 Alternatively, packages can use the <code>X-DH-Compat</code> field in
 <code>debian/control</code> to specify debhelper compat level.
 Note that using a compat file is not accepted starting compat level 14.
 Please refer to the debhelper documentation on how to create the
 compat file and the differences between each compat level.
See-Also: https://lists.debian.org/debian-devel-changes/2012/01/msg01335.html, 
 https://lists.debian.org/debian-devel/2026/02/msg00357.html,
 debhelper(7)

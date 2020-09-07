Tag: package-does-not-use-debhelper-or-cdbs
Severity: pedantic
Check: debhelper
Explanation: This package does not appear to use a build system helper such as
 debhelper or cdbs.
 .
 It is recommended that packages use such tools as they avoid a large
 number of common errors and tedious boilerplate as well as permit
 distribution-wide changes to packages and reduce the "bus factor" &
 barriers to entry from external contributors.
See-Also: debhelper(7), dh(1), https://build-common.alioth.debian.org/

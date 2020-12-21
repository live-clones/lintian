Tag: no-versioned-debhelper-prerequisite
Severity: warning
Check: debhelper
Renamed-From:
 package-needs-versioned-debhelper-build-depends
 package-lacks-versioned-build-depends-on-debhelper
Explanation: The package either doesn't declare a versioned build dependency on
 debhelper or does not declare a versioned build dependency on a new
 enough version of debhelper to satisfy the declared compatibility level.
 .
 The required version of debhelper is not guaranteed to be satisfied
 in all supported releases of Debian and therefore this may lead to
 a build failure.
 .
 The recommended practice is to always declare an explicit versioned
 dependency on debhelper equal to or greater than the compatibility level
 used by the package, even if the versioned dependency isn't strictly
 necessary. Having a versioned dependency also helps with backports to
 older releases and correct builds on partially updated systems.
 .
 Packages not using an experimental or beta compatibility level may
 alternatively Build-Depend on the debhelper-compat virtual package, for
 example:
 .
  Build-Depends: debhelper-compat (= 13)
 .
 Note if you are using a compat level marked as experimental (such as
 compat 12 in debhelper 11.4~) please explicitly override this tag.

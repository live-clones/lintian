Tag: package-lacks-versioned-build-depends-on-debhelper
Severity: pedantic
Check: debhelper
Explanation: The package either doesn't declare a versioned build dependency on
 debhelper or does not declare a versioned build dependency on a new
 enough version of debhelper to satisfy the declared compatibility level.
 .
 Recommended practice is to always declare an explicit versioned
 dependency on debhelper equal to or greater than the compatibility level
 used by the package, even if the versioned dependency isn't strictly
 necessary. Having a versioned dependency also helps with backports to
 older releases and correct builds on partially updated systems.
See-Also: debhelper(7)

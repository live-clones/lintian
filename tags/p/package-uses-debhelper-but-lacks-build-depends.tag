Tag: package-uses-debhelper-but-lacks-build-depends
Severity: error
Check: debhelper
Explanation: If a package uses debhelper, it must declare a Build-Depends
 on debhelper or on the debhelper-compat virtual package. For example:
 .
  Build-Depends: debhelper (&gt;= 13~)
 .
  Build-Depends: debhelper-compat (= 13)

Tag: no-op-testsuite
Severity: warning
Check: testsuite
Explanation: This package declares a single autopkgtest which will always
 pass as it uses a "no-op" command such as <code>/bin/true</code>.
 .
 As the results of autopkgtests influence migration from unstable
 to testing this is undesirable and could be even considered an
 unfair or unwarranted "advantage". Installability of packages is
 better tested with piuparts which is also used to influence
 testing migration.
 .
 Please update your autopkgtest to actually test the binary package(s)
 when installed.
See-Also: https://ci.debian.net/doc/

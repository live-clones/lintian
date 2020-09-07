Tag: testsuite-dependency-has-unparsable-elements
Severity: warning
Check: testsuite
Explanation: Lintian cannot parse the Depends field for the given autopkgtest.
 .
 Please double check that dependency the syntax is correct.
 .
 Note that Lintian has a whitelist of known "special" dependencies
 permitted by autopkgtest (e.g. @builddeps@). Lintian does not accept
 these as a part of an OR-clause.
See-Also: https://salsa.debian.org/ci-team/autopkgtest/tree/master/doc/README.package-tests.rst

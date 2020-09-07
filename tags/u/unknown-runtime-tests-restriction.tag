Tag: unknown-runtime-tests-restriction
Severity: pedantic
Check: testsuite
Explanation: A paragraph in debian/tests/control mentions a non-standard
 value for the Restrictions field. Though allowed, this may indicate an
 error, as the whole paragraph will be ignored.
See-Also: https://salsa.debian.org/ci-team/autopkgtest/tree/master/doc/README.package-tests.rst

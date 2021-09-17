Tag: missing-tests-control
Severity: error
Check: testsuite
Renamed-From:
 testsuite-autopkgtest-missing
Explanation: The source package declares the generic <code>Testsuite: autopkgtest</code>
 field but provides no <code>debian/tests/control</code> file.
 .
 The control file is not needed when a specialized test suite such as
 <code>autopkgtest-pkg-perl</code> is being used.
See-Also: https://salsa.debian.org/ci-team/autopkgtest/tree/master/doc/README.package-tests.rst

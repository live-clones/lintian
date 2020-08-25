Tag: debian-tests-control-autodep8-is-obsolete
Severity: warning
Check: testsuite
See-Also: autodep8(1)
Explanation: The specified autopkgtest control file is considered obsolete.
 .
 Before autodep8 version 0.17 and autopkgtest version 5.7 if a
 maintainer wished to add tests to the set of tests generated
 by autodep8 they provided those tests in a file named
 <code>debian/tests/control.autodep8</code>.
 .
 It is now prefered to declare the additional tests in the regular
 <code>debian/tests/control</code> file so that <code>dpkg-source</code> can
 pick up the test dependencies.
 .
 When configured to run autodep8 tests, autopkgtest will run the
 additional tests and the autodep8 tests when <code>debian/control</code>
 has the proper <code>Testsuite: autopkgtest-&ast;</code> in the source
 headers.
 .
 Please merge the specified file into <code>debian/tests/control</code>.

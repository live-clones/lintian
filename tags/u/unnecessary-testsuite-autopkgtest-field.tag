Tag: unnecessary-testsuite-autopkgtest-field
Severity: warning
Check: testsuite
Explanation: You do not need to specify a <code>Testsuite: autopkgtest</code> field if
 a <code>debian/tests/control</code> file exists. It is automatically added by
 dpkg-source(1) since dpkg 1.17.1.
 .
 Please remove this line from your <code>debian/control</code> file.
Renamed-From:
 unnecessary-testsuite-autopkgtest-header

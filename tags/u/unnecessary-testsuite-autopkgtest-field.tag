Tag: unnecessary-testsuite-autopkgtest-field
Severity: warning
Check: testsuite
Explanation: You do not need to specify a <tt>Testsuite: autopkgtest</tt> field if
 a <tt>debian/tests/control</tt> file exists. It is automatically added by
 dpkg-source(1) since dpkg 1.17.1.
 .
 Please remove this line from your <tt>debian/control</tt> file.
Renamed-From:
 unnecessary-testsuite-autopkgtest-header

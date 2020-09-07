Tag: pkg-js-autopkgtest-test-is-missing
Severity: warning
Check: languages/javascript/nodejs
Explanation: The <code>Testsuite:</code> field for this package points to
 <code>autopkgtest-pkg-nodejs</code> which attempts to execute
 the specified file during autopkgtests.
 .
 When this file is missing, only a simple <code>node require("&lt;module
 name&gt;")</code> is launched. This may be insufficient to really test this
 nodejs module
 (see <code>/usr/share/doc/pkg-js-autopkgtest/README.md</code>).

Tag: pkg-js-tools-test-is-missing
Severity: warning
Check: languages/javascript/nodejs
Explanation: The <code>debian/rules</code> file for this package uses <code>--with
 nodejs</code> which attempts to execute the specified file when running
 autopkgtests.
 .
 When this file is missing, only a simple <code>node require(".")</code> is
 launched which may be insufficient to really test this nodejs module.
 .
 Please specify the upstream testsuite (or a custom one) in
 <code>debian/tests/pkg-js/test</code>
 (see <code>/usr/share/doc/pkg-js-tools/README.md.gz</code>).

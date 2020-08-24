Tag: pkg-js-tools-test-is-missing
Severity: warning
Check: languages/javascript/nodejs
Explanation: The <tt>debian/rules</tt> file for this package uses <tt>--with
 nodejs</tt> which attempts to execute the specified file when running
 autopkgtests.
 .
 When this file is missing, only a simple <tt>node require(".")</tt> is
 launched which may be insufficient to really test this nodejs module.
 .
 Please specify the upstream testsuite (or a custom one) in
 <tt>debian/tests/pkg-js/test</tt>
 (see <tt>/usr/share/doc/pkg-js-tools/README.md.gz</tt>).

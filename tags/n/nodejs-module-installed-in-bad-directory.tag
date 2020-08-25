Tag: nodejs-module-installed-in-bad-directory
Severity: warning
Check: languages/javascript/nodejs
Explanation: This package installs the specified nodejs module in a location that
 does not match its name declared in package.json. This renders this module
 unusable using a simple <code>require()</code>.
 .
 You can use pkg-js-tools auto installer to avoid this, see
 <code>/usr/share/doc/pkg-js-tools/README.md.gz</code>

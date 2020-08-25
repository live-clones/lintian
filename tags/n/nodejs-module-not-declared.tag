Tag: nodejs-module-not-declared
Severity: warning
Check: languages/javascript/nodejs
Explanation: This package installs the specified nodejs module in a nodejs root
 directory without declaring it in "Provides:" field in debian/control.
 .
 You can use <code>Provides: ${nodejs:Provides}</code> provided by pkg-js-tools
 to fix this. See <code>/usr/share/doc/pkg-js-tools/README.md.gz</code> for more.

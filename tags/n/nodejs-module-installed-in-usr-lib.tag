Tag: nodejs-module-installed-in-usr-lib
Severity: warning
Check: languages/javascript/nodejs
Explanation: This package installs the specified file under <code>/usr/lib/nodejs</code>.
 Since the release of Buster, these files should be installed under
 <code>/usr/share/nodejs</code> (for arch <i>independent</i> modules) or
 <code>/usr/lib/$DEB_HOST_MULTIARCH/nodejs</code> (for arch <i>dependent</i> modules)
 instead.
 .
 You can use pkg-js-tools auto installer to avoid this, see
 <code>/usr/share/doc/pkg-js-tools/README.md.gz</code>

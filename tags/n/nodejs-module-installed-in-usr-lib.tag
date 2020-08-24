Tag: nodejs-module-installed-in-usr-lib
Severity: warning
Check: languages/javascript/nodejs
Explanation: This package installs the specified file under <tt>/usr/lib/nodejs</tt>.
 Since the release of Buster, these files should be installed under
 <tt>/usr/share/nodejs</tt> (for arch <i>independent</i> modules) or
 <tt>/usr/lib/$DEB_HOST_MULTIARCH/nodejs</tt> (for arch <i>dependent</i> modules)
 instead.
 .
 You can use pkg-js-tools auto installer to avoid this, see
 <tt>/usr/share/doc/pkg-js-tools/README.md.gz</tt>

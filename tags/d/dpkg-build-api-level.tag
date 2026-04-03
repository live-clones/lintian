Tag: dpkg-build-api-level
Severity: classification
Check: debian/dpkg-build-api
See-Also: dpkg-build-api(7)
Explanation: This is the dpkg build API level declared by the source package.
 .
 The source package dpkg build API level can be declared either through build
 dependencies in the <code>debian/control</code> file or via the
 <code>DPKG&lowbar;BUILD&lowbar;API</code> environment variable set in the
 <code>debian/rules</code> script. If the level is not explicitly declared, it
 defaults to zero which is the current global level.

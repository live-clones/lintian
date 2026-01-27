Tag: debian-rules-overrides-dpkg-build-api
Severity: warning
Check: debian/dpkg-build-api
See-Also: dpkg-build-api(7)
Explanation: The source package dpkg build API level declared via the
 <code>DPKG&lowbar;BUILD&lowbar;API</code> environment variable in the
 <code>debian/rules</code> script contradicts with the version of the
 <code>dpkg-build-api</code> virtual package among build dependencies in the
 <code>debian/control</code> file. The environment variable has precedence but
 it is confusing and may have incomplete effect.
 .
 Please use only one way to declare the dpkg build API level in your source
 package.

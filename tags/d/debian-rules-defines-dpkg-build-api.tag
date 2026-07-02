Tag: debian-rules-defines-dpkg-build-api
Severity: warning
Check: debian/dpkg-build-api
See-Also: dpkg-buildapi(1)
Explanation: <code>DPKG&lowbar;BUILD&lowbar;API</code> is an internal
 environment variable and should not be defined in the
 <code>debian/rules</code> script. The source package dpkg build API level
 cannot be properly declared in <code>debian/rules</code> because build drivers
 (such as dpkg-buildpackage) do not recognize it in this case.
 .
 Please remove the <code>DPKG&lowbar;BUILD&lowbar;API</code> declaration from
 the <code>debian/rules</code> script.

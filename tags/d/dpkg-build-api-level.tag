Tag: dpkg-build-api-level
Severity: classification
Check: debian/dpkg-build-api
See-Also: dpkg-build-api(7)
Explanation: This is the dpkg build API level declared by the source package.
 .
 The source package dpkg build API level is recommended to be declared through
 build dependencies in the <code>debian/control</code> file. It is intended to
 gradually introduce new specific behaviors without breaking the global build
 interface guarantees. If the level is not explicitly declared, it defaults to
 zero which is the current global level.

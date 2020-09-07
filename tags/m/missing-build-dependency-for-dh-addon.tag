Tag: missing-build-dependency-for-dh-addon
Severity: error
Check: debhelper
Explanation: The source package appears to be using a dh addon but doesn't build
 depend on the package that actually provides it. If it uses it, it must
 build depend on it.

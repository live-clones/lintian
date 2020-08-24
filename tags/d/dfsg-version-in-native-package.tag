Tag: dfsg-version-in-native-package
Severity: warning
Check: fields/version
Explanation: The version number of this package contains "dfsg", but it's a
 native package. "dfsg" is conventionally used in the upstream version of
 packages that are repackaged for Debian Free Software Guidelines
 compliance reasons. The convention doesn't make sense in native
 packages.

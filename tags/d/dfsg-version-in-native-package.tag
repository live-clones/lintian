Tag: dfsg-version-in-native-package
Severity: warning
Check: fields/version/repack/native
Explanation: The version number contains the string <code>dfsg</code> but
 the sources are native.
 .
 The string <code>dfsg</code> is used in Debian versions to indicate that
 that the sources were repackaged in order to comply with the Debian Free
 Software Guidelines, but all native packages should comply with the
 guidelines.
See-Also:
 https://wiki.debian.org/DebianFreeSoftwareGuidelines,
 https://wiki.debian.org/DFSGLicenses

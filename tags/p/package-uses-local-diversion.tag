Tag: package-uses-local-diversion
Severity: error
Check: scripts
See-Also: policy 3.9
Explanation: The maintainer script calls dpkg-divert with <code>--local</code> or
 without <code>--package</code>. This option is reserved for local
 administrators and must never be used by a Debian package.

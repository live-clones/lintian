Tag: package-uses-local-diversion
Severity: error
Check: maintainer-scripts/diversion
Explanation: The named maintainer script calls <code>dpkg-divert</code> with
 <code>--local</code> or without <code>--package</code>. Those usages are
 reserved for local administrators and must not be used by a Debian package.
See-Also:
 policy 3.9

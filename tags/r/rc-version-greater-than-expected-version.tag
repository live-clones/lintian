Tag: rc-version-greater-than-expected-version
Severity: warning
Check: debian/changelog
See-Also: policy 5.6.12
Explanation: The package appears to be a release candidate or preview release, but
 the version sorts higher than the expected final release.
 .
 For non-native packages, the check examines the upstream version.
 For native packages, it looks at the Debian maintainer's revision.

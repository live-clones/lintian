Tag: odd-historical-debian-changelog-version
Severity: warning
Check: debian/changelog
Explanation: The version string in a historical changelog entry was not parsed
 correctly. Usually, that means it does not conform to policy.
 .
 It can also happen when a package changes from native to non-native
 (or the other way around). Historical entries are then in a nonconforming
 format.
 .
 As a side note, Lintian cannot tell whether a package changed from
 naive to non-native, or the other way around. It can only say whether
 the historical changelog entries comply with the current nativeness of a
 package.
See-Also: policy 5.6.12

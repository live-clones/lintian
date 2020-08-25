Tag: backports-changes-missing
Severity: info
Check: fields/distribution
Explanation: The changes file only has changelog entries from a single version. It
 is recommended for backports to include all changes since (old)stable or
 the previous backport. This can be done by adding the '-v' option to the
 build with the appropriate version.
See-Also: http://backports.debian.org/Contribute/, Bug#785084

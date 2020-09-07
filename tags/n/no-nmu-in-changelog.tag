Tag: no-nmu-in-changelog
Severity: warning
Check: nmu
Renamed-From: changelog-should-mention-nmu
Explanation: When you NMU a package, that fact should be mentioned on the first line
 in the changelog entry. Use the words "NMU" or "Non-maintainer upload"
 (case insensitive).
 .
 Maybe you didn't intend this upload to be a NMU, in that case, please
 double-check that the most recent entry in the changelog is byte-for-byte
 identical to the maintainer or one of the uploaders. If this is a local
 package (not intended for Debian), you can suppress this warning by
 putting "local" in the version number or "local package" on the first
 line of the changelog entry.
See-Also: devref 5.11.3

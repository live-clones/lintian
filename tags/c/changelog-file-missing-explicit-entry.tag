Tag: changelog-file-missing-explicit-entry
Severity: warning
Check: debian/changelog
Explanation: The latest changelog file for this package specifies a version in
 the form of 1.2-3+deb8u1, 1.2-3+nmu4 (or similar) but this does not
 follow from a corresponding 1.2-3 changelog stanza.
 .
 This suggests that changes were merged into a single entry. This is
 suboptimal as it makes it more difficult for users to determine which
 upload fixed a particular bug.
See-Also: devref 5.8.5.4, devref 5.11.2, devref 5.14.3, Bug#916877

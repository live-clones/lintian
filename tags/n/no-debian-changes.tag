Tag: no-debian-changes
Severity: warning
Check: cruft
Renamed-From:
 empty-debian-diff
Explanation: This non-native package makes no changes to the upstream sources
 in the Debian-related files.
 .
 Maybe a mistake was made when the upstream tarball was created, or maybe this
 package is really a native package but was built non-native by mistake.
 .
 Debian packaging is sometimes maintained as part of upstream, but that is not
 recommended as best practice. Please make this package native, if the software
 is only for Debian. Otherwise, please remove the <code>debian</code> directory
 from upstream releases and add it in the Debian packaging.
 .
 Format 1.0 packages are subject to the restriction that the diff cannot remove
 files from the <code>debian</code> directory. For Format 3.0 packages, the
 <code>debian</code> directory is automatically purged during unpacking.

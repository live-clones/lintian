Tag: initial-upload-closes-no-bugs
Severity: warning
Check: debian/changelog
Renamed-From: new-package-should-close-itp-bug
Explanation: This package appears to be the first packaging of a new upstream
 software package (there is only one changelog entry and the Debian
 revision is 1), but it does not close any bugs. The initial upload of a
 new package should close the corresponding ITP bug for that package.
 .
 This warning can be ignored if the package is not intended for Debian or
 if it is a split of an existing Debian package.
See-Also: devref 5.1

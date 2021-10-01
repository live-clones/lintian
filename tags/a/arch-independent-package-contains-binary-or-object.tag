Tag: arch-independent-package-contains-binary-or-object
Severity: error
Check: binaries/architecture
Explanation: The package contains a binary or object file but is tagged
 Architecture: all.
 .
 If this package contains binaries or objects for cross-compiling or
 binary blobs for other purposes independent of the host architecture
 (such as BIOS updates or firmware), please add a Lintian override.

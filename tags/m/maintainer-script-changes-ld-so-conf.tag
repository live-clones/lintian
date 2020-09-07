Tag: maintainer-script-changes-ld-so-conf
Severity: error
Check: scripts
Renamed-From: maintainer-script-should-not-modify-ld-so-conf
Explanation: This package appears to modify <code>/etc/ld.so.conf</code> and does not
 appear to be part of libc. Packages installing shared libraries in
 non-standard locations were previously permitted to modify
 /etc/ld.so.conf to add the non-standard path, but this permission was
 removed in Policy 3.8.3.
 .
 Packages containing shared libraries should either install them into
 <code>/usr/lib</code> or should require binaries built against them to set
 RPATH to find the library at run-time. Installing libraries in a
 different directory and modifying the run-time linker path is equivalent
 to installing them into <code>/usr/lib</code> except now conflicting library
 packages may cause random segfaults and difficult-to-debug problems
 instead of conflicts in the package manager.

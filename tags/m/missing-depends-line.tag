Tag: missing-depends-line
Severity: warning
Check: binaries
Explanation: The package contains an ELF binary with dynamic dependencies,
 but does not have a Depends line in its control file. This usually
 means that a call to <code>dpkg-shlibdeps</code> is missing from the
 package's <code>debian/rules</code> file.

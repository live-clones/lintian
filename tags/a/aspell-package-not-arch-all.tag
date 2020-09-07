Tag: aspell-package-not-arch-all
Severity: warning
Check: fields/architecture
Explanation: This package appears to be an aspell dictionary package, but it is
 not Architecture: all. The binary hashes should be built at install-time
 by calling aspell-autobuildhash, so the contents of the package should be
 architecture-independent.
See-Also: aspell-autobuildhash(8)

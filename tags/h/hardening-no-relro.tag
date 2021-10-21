Tag: hardening-no-relro
Severity: warning
Check: binaries/hardening
Explanation: This package provides an ELF binary that lacks the "read-only
 relocation" link flag. This package was likely not built with the
 default Debian compiler flags defined by <code>dpkg-buildflags</code>.
 If built using <code>dpkg-buildflags</code> directly, be sure to import
 <code>LDFLAGS</code>.
See-Also: https://wiki.debian.org/Hardening

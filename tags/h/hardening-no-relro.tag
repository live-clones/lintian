Tag: hardening-no-relro
Severity: warning
Check: binaries
Explanation: This package provides an ELF binary that lacks the "read-only
 relocation" link flag. This package was likely not built with the
 default Debian compiler flags defined by <tt>dpkg-buildflags</tt>.
 If built using <tt>dpkg-buildflags</tt> directly, be sure to import
 <tt>LDFLAGS</tt>.
See-Also: https://wiki.debian.org/Hardening

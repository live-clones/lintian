Tag: hardening-no-bindnow
Severity: info
Check: binaries/hardening
Explanation: This package provides an ELF binary that lacks the "bindnow"
 linker flag.
 .
 This is needed (together with "relro") to make the "Global Offset
 Table" (GOT) fully read-only. The bindnow feature trades startup
 time for improved security. Please consider enabling this feature
 or consider overriding the tag (possibly with a comment about why).
 .
 If you use <code>dpkg-buildflags</code>, you may have to add
 <code>hardening=+bindnow</code> or <code>hardening=+all</code> to
 <code>DEB&lowbar;BUILD&lowbar;MAINT&lowbar;OPTIONS</code>.
 .
 The relevant compiler flags are set in <code>LDFLAGS</code>.
See-Also: https://wiki.debian.org/Hardening

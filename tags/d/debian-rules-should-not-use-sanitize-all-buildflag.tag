Tag: debian-rules-should-not-use-sanitize-all-buildflag
Severity: error
Check: debian/rules
Explanation: This package's <code>debian/rules</code> file contains a
 <code>DEB&lowbar;BUILD&lowbar;MAINT&lowbar;OPTIONS</code> assignment that enables the
 <code>sanitize=+all</code> build flag.
 .
 This option instructs the compiler to enable options designed to
 protect the binary against memory corruptions, memory leaks, use after
 free, threading data races, and undefined behavior bugs.
 .
 However, this options should not be used for production Debian binaries
 as they can reduce reliability for conformant code, reduce security or
 even functionality.
 .
 Please remove the reference to <code>sanitize=+all</code>.
See-Also: dpkg-buildflags(1), Bug#895811

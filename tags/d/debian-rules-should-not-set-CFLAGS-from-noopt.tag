Tag: debian-rules-should-not-set-CFLAGS-from-noopt
Severity: warning
Check: debian/rules
See-Also: dpkg-buildflags(1)
Explanation: The <code>debian/rules</code> file for this package appears to set
 <code>CFLAGS</code> if the value of <code>DEB&lowbar;BUILD&lowbar;OPTIONS</code> contains
 <code>noopt</code>.
 .
 This has been obsoleted in favour of <code>dpkg-buildflags</code>.

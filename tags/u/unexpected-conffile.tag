Tag: unexpected-conffile
Severity: error
Check: conffiles
Explanation: The conffiles control file lists this path, but you should
 ship no such file.
 .
 This condition presently occurs only when <code>DEBIAN/conffiles</code>
 includes the instruction <code>remove-on-upgrade</code>.
See-Also:
 deb-conffiles(5)

Tag: declares-possibly-conflicting-debhelper-compat-versions
Severity: error
Check: debhelper
See-Also: debhelper(7)
Explanation: The source package declares the debhelper compatibility version
 both in the <code>debian/compat</code> file and in the <code>debian/rules</code>
 file or in <code>debian/control</code>. If these ever get out of
 synchronisation, the package may not build as expected.

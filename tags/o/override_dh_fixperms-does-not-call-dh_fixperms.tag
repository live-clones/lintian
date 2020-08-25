Tag: override_dh_fixperms-does-not-call-dh_fixperms
Severity: warning
Check: debian/rules
Explanation: The <code>debian/rules</code> file for this package has an
 <code>override&lowbar;dh&lowbar;fixperms</code> target that does not reference
 <code>dh&lowbar;fixperms</code>.
 .
 This can result in packages inheriting the <code>umask(2)</code> of the build
 process, rendering the package unreproducible.
 .
 Please add a call to <code>dh&lowbar;fixperms</code>.
See-Also: Bug#885909

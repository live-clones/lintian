Tag: postrm-has-useless-call-to-update-menus
Severity: warning
Check: menus
Explanation: The <code>postrm</code> maintainer script calls the
 <code>update-menus</code> command, but no files are being
 installed into <code>/etc/menu-methods</code>,
 <code>/usr/share/menu</code>, or <code>/usr/lib/menu</code>.

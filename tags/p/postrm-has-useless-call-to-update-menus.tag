Tag: postrm-has-useless-call-to-update-menus
Severity: warning
Check: menus
Explanation: The <code>postrm</code> script calls the <code>update-menus</code> program
 though no file is installed in <code>/etc/menu-methods</code>,
 <code>/usr/share/menu</code>, or <code>/usr/lib/menu</code>.

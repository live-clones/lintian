Tag: postrm-has-useless-call-to-update-menus
Severity: warning
Check: menus
Explanation: The <tt>postrm</tt> script calls the <tt>update-menus</tt> program
 though no file is installed in <tt>/etc/menu-methods</tt>,
 <tt>/usr/share/menu</tt>, or <tt>/usr/lib/menu</tt>.

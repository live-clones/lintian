Tag: postrm-does-not-call-updatemenus
Severity: error
Check: menus
Explanation: Since the package installs a file in <tt>/etc/menu-methods</tt>,
 <tt>/usr/share/menu</tt>, or <tt>/usr/lib/menu</tt>, the package should
 probably call the <tt>update-menus</tt> command in it's <tt>postrm</tt>
 script.
 .
 For example, use the following code in your maintainer script:
 .
  if which update-menus &gt; /dev/null; then update-menus ; fi
See-Also: menu 4.2

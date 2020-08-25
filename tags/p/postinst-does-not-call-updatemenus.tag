Tag: postinst-does-not-call-updatemenus
Severity: error
Check: menus
Explanation: Since the package installs a file in <code>/etc/menu-methods</code>,
 <code>/usr/share/menu</code>, or <code>/usr/lib/menu</code>, the package should
 probably call the <code>update-menus</code> command in it's <code>postinst</code>
 script.
 .
 For example, use the following code in your maintainer script:
 .
  if which update-menus &gt; /dev/null; then update-menus ; fi
See-Also: menu 4.2

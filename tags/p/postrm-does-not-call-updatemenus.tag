Tag: postrm-does-not-call-updatemenus
Severity: error
Check: menus
Explanation: The package installs a file in <code>/etc/menu-methods</code>,
 <code>/usr/share/menu</code>, or <code>/usr/lib/menu</code>, but does not
 call the <code>update-menus</code> command in the <code>postrm</code>
 script.
 .
 For example, you use the following code in your maintainer script:
 .
     if which update-menus &gt; /dev/null; then
         update-menus
     fi
See-Also:
 menu-manual 4.2

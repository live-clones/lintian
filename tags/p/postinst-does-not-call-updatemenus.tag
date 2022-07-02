Tag: postinst-does-not-call-updatemenus
Severity: error
Check: menus
Explanation: The package installs a file into <code>/etc/menu-methods</code>,
 <code>/usr/share/menu</code>, or <code>/usr/lib/menu</code>, but does not
 call the <code>update-menus</code> command in the <code>postinst</code>
 maintainer script.
 .
 For example, you ca use the following code in your maintainer script:
 .
     if which update-menus &gt; /dev/null; then
         update-menus
     fi
See-Also:
 menu-manual 4.2

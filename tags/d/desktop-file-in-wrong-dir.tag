Tag: desktop-file-in-wrong-dir
Severity: warning
Check: files/desktop
Explanation: The package contains a <code>.desktop</code> file in an obsolete
 folder such as <code>/usr/share/gnome/apps</code>.
 .
 According to the latest draft of the <code>menu</code> specification available
 on freedesktop.org, <code>.desktop</code> files intended to create menus should
 be placed in <code>/usr/share/applications</code>.

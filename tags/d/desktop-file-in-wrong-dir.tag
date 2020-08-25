Tag: desktop-file-in-wrong-dir
Severity: warning
Check: files/desktop
Explanation: The package contains a .desktop file in an obsolete directory.
 According to the menu-spec draft on freedesktop.org, those .desktop files
 that are intended to create a menu should be placed in
 <code>/usr/share/applications</code>, not <code>/usr/share/gnome/apps</code>.

Tag: stray-devhelp-documentation
Severity: warning
Check: documentation/devhelp
Renamed-From:
 package-contains-devhelp-file-without-symlink
Explanation: The named file is not in the Devhelp search path
 (<code>/usr/share/devhelp/books</code> or  <code>/usr/share/gtk-doc/html</code>)
 and also not located in a directory that is accessible via a symbolic link from
 that search path. Devhelp cannot find that file.
 .
 For Devhelp documentation installed outside the search path (such as
 <code>/usr/share/doc</code>), create a symbolic link in
 <code>/usr/share/gtk-doc/html</code> that points to the documentation directory.
See-Also:
 https://apps.gnome.org/app/org.gnome.Devhelp/

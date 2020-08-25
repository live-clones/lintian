Tag: package-contains-mimeinfo.cache-file
Severity: error
Check: mimeinfo
Explanation: This package contains a file named <code>mimeinfo.cache</code>,
 possibly compressed, in <code>/usr/share/applications</code>. This file is
 generated automatically by update-desktop-database when a package
 containing <code>.desktop</code> files associated to MIME types is installed.
 Some upstream build systems create it automatically, but it must not be
 included in a package since it needs to be generated dynamically based on
 the installed .desktop files on the system.

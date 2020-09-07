Tag: menu-icon-missing
Severity: warning
Check: menu-format
Explanation: This icon file couldn't be found. If the path to the icon in the
 menu file is an absolute path, make sure that icon exists at that path in
 the package. If the path is relative or a simple filename, make sure the
 icon is installed in <code>/usr/share/pixmaps</code>, the default location.
 .
 If the icon is provided by another package on which this package
 depends, Lintian may not be able to determine that icon pages are
 available. In this case, after confirming that all icons are
 available after this package and its dependencies are installed,
 please add a Lintian override.
See-Also: menu 3.7

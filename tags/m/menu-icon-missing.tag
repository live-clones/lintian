Tag: menu-icon-missing
Severity: warning
Check: menu-format
Explanation: The given icon file was not found.
 .
 If the path to the icon that is listed in the menu file is absolute,
 make sure that your package also installs the icon at that path.
 .
 If the path is just a filename or othewise a relative path, make sure
 the icon is being installed in <code>/usr/share/pixmaps</code>, which
 is the default location.
 .
 If the icon is provided by another package on which this package
 depends, Lintian may not be able to determine if the icon is
 available. In that case, please override this tag.
See-Also:
 menu-manual 3.7

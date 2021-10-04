Tag: lacks-versioned-link-to-shared-library
Severity: error
Check: libraries/shared/links
Renamed-From:
 ldconfig-symlink-missing-for-shlib
Explanation: The package should not only include the shared library itself, but also
 the symbolic link which ldconfig would produce. (This is necessary, so 
 that the link gets removed by dpkg automatically when the package
 gets removed.) If the symlink is in the package, check that the SONAME of the
 library matches the info in the shlibs file.
See-Also:
 policy 8.1

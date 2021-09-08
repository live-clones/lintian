Tag: excludes-files-in-native-package
Severity: error
Check: debian/copyright/dep5
Renamed-From:
 copyright-excludes-files-in-native-package
Explanation: The given Debian <code>copyright</code> file notes excluded files with
 the <code>Files-Excluded</code> field, but the package is native.
 .
 Native packages cannot be repackaged. Please remove the field from
 the given <code>copyright</code> file or make the package non-native.

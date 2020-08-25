Tag: copyright-excludes-files-in-native-package
Severity: error
Check: debian/copyright/dep5
Explanation: The Debian copyright notes excluded files with the <code>Excluded-Files</code> field,
 but the package is native.
 .
 Native packages cannot be repackaged. Please remove the field from
 <code>debian/copyright</code> or make the package non-native.

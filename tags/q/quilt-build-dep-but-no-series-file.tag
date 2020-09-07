Tag: quilt-build-dep-but-no-series-file
Severity: warning
Check: debian/patches/quilt
Explanation: Using quilt requires you to explicitly list all patches you want
 to apply in debian/patches/series. This package build-depends on quilt,
 but does not provide a patch list. You should either remove the quilt
 build dependency or add a series file.
 .
 Note that an empty file cannot be represented in the Debian diff, so an
 empty series file will disappear in the source package. If you intended
 for the series file to be empty, add a comment line.

Tag: package-installs-appimage
Severity: error
Check: files/appimage-check
Type: binary
Explanation: AppImage file must not be included in the package.
 .
 AppImages are not a standard packaging format for Debian and may cause issues
 with dependency management and system integration. Please repackage the
 application as a proper Debian package.

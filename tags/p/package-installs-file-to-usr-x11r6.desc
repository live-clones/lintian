Tag: package-installs-file-to-usr-x11r6
Severity: error
Check: desktop/x11
Explanation: Packages using the X Window System should not be configured to install
 files under the /usr/X11R6/ directory. Debian has switched to the modular
 X tree which now uses regular FHS paths and all packages should follow.
 .
 Programs that use GNU autoconf and automake are usually easily configured
 at compile time to use /usr/ instead of /usr/X11R6/. Packages that use
 imake must build-depend on xutils-dev (&gt;= 1:1.0.2-2) for the correct
 paths.
See-Also: policy 11.8.7

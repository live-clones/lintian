Tag: link-to-shared-library-in-wrong-package
Severity: warning
Check: libraries/shared/links
Renamed-From:
 non-dev-pkg-with-shlib-symlink
Explanation: Although this package is not a "-dev" package, it installs a
 "libsomething.so" symbolic link referencing the corresponding shared
 library. When the link doesn't include the version number, it is used by
 the linker when other programs are built against this shared library.
 .
 Shared libraries are supposed to place such symbolic links in their
 respective "-dev" packages, so it is a bug to include it with the main
 library package.
 .
 However, if this is a small package which includes the runtime and the
 development libraries, this is not a bug. In the latter case, please
 override this warning.
See-Also:
 policy 8.4

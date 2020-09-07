Tag: quilt-series-but-no-build-dep
Severity: warning
Check: debian/patches/quilt
Explanation: The package contains a debian/patches/series file usually used by
 quilt to apply patches at build time, but quilt is not listed in the
 build dependencies.
 .
 You should either remove the series file if it's effectively not useful
 or add quilt to the build-dependencies if quilt is used during the build
 process.
 .
 If you don't need quilt during build but only during maintenance work,
 then you can override this warning.

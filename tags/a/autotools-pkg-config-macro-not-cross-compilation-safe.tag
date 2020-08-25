Tag: autotools-pkg-config-macro-not-cross-compilation-safe
Severity: warning
Check: cruft
Explanation: The package appears to use <code>AC_PATH_PROG</code> to discover the
 location of <code>pkg-config(1)</code>. This macro fails to select the correct
 version to support cross-compilation.
 .
 A better way would be to use the <code>PKG_PROG_PKG_CONFIG</code> macro from
 <code>pkg.m4</code> and then using the <code>$PKG_CONFIG</code> shell variable.
See-Also: #884798

Tag: autotools-pkg-config-macro-not-cross-compilation-safe
Severity: warning
Check: build-systems/autotools
Explanation: The package appears to use <code>AC&lowbar;PATH&lowbar;PROG</code> to discover the
 location of <code>pkg-config(1)</code>. This macro fails to select the correct
 version to support cross-compilation.
 .
 A better way would be to use the <code>PKG&lowbar;PROG&lowbar;PKG&lowbar;CONFIG</code> macro from
 <code>pkg.m4</code> and then using the <code>$PKG&lowbar;CONFIG</code> shell variable.
See-Also: Bug#884798

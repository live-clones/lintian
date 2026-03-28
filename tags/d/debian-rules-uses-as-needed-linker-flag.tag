Tag: debian-rules-uses-as-needed-linker-flag
Severity: pedantic
Check: debian/rules
Explanation: The <code>debian/rules</code> file for this package uses the
 <code>-Wl,--as-needed</code> linker flag.
 .
 Since Bullseye, <code>--as-needed</code> is now ran by default. As such, it
 should no longer be necessary to inject this into the build process.

Tag: debian-rules-uses-as-needed-linker-flag
Severity: pedantic
Experimental: yes
Check: debian/rules
Explanation: The <code>debian/rules</code> file for this package uses the
 <code>-Wl,--as-needed</code> linker flag.
 .
 The bullseye toolchain defaults to linking with <code>--as-needed</code> and
 therefore it should no longer be necessary to inject this into the
 build process.
 .
 However, it is not safe to make this change if the package will target
 the buster distribution such as via backports to the buster-bpo /
 stable-bpo distribution or, during the bookworm cycle itself, the
 oldstable-bpo distribution.

Tag: debian-rules-uses-as-needed-linker-flag
Severity: pedantic
Experimental: yes
Check: debian/rules
Explanation: The <tt>debian/rules</tt> file for this package uses the
 <tt>-Wl,--as-needed</tt> linker flag.
 .
 The bullseye toolchain defaults to linking with <tt>--as-needed</tt> and
 therefore it should no longer be necessary to inject this into the
 build process.
 .
 However, it is not safe to make this change if the package will target
 the buster distribution such as via backports to the buster-bpo /
 stable-bpo distribution or, during the bookworm cycle itself, the
 oldstable-bpo distribution.

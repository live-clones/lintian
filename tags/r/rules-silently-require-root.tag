Tag: rules-silently-require-root
Severity: info
Check: debian/control
Renamed-From:
 should-specify-rules-requires-root
Explanation: This package builds a binary package containing at least one path
 with a UNIX ownership other than "root:root". It therefore requires
 <code>fakeroot(1)</code> or similar to build its binary targets.
 .
 Traditionally, Debian packages have required root privileges for some
 debian/rules target requiring a split between build and binary targets.
 This makes the builds slower due to the increased amount of invocations
 as well as the overhead of fakeroot itself.
 .
 By declaring when a package really does require root privileges the
 default, archive-wide, behaviour can be switched, optimising packaging
 build times in the common case.
 .
 Please specify (eg.) <code>Rules-Requires-Root: binary-targets</code> in
 the <code>debian/control</code> source stanza.
See-Also: /usr/share/doc/dpkg-dev/rootless-builds.txt.gz, policy 4.9.2, policy 5.6.31

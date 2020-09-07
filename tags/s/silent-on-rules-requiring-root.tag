Tag: silent-on-rules-requiring-root
Severity: pedantic
Check: debian/control
Renamed-From:
 rules-requires-root-missing
Explanation: The <code>debian/control</code> file is missing an explicit
 <code>Rules-Requires-Root</code> field.
 .
 Traditionally, Debian packages have required root privileges for some
 debian/rules target requiring a split between build and binary targets.
 This makes the builds slower due to the increased amount of invocations
 as well as the overhead of fakeroot itself.
 .
 Please specify (eg.) <code>Rules-Requires-Root: no</code> in the
 <code>debian/control</code> source stanza, but packagers should
 verify using <code>diffoscope(1)</code> that the binaries built with this
 field present are identical.
See-Also: /usr/share/doc/dpkg-dev/rootless-builds.txt.gz, policy 4.9.2, policy 5.6.31

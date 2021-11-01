Tag: rules-require-root-explicitly
Severity: classification
Check: debian/control/field/rules-requires-root
Renamed-From:
 rules-requires-root-explicitly
Explanation: The sources require <code>fakeroot(1)</code> or similar to build
 the installation packages and also explicitly declare that need via the field
 <code>Rules-Requires-Root</code> in the source stanza of the file
 <code>debian/control</code>.
See-Also:
 /usr/share/doc/dpkg-dev/rootless-builds.txt.gz,
 policy 4.9.2,
 policy 5.6.31

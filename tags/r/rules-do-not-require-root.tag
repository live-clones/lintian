Tag: rules-do-not-require-root
Severity: classification
Check: debian/control/field/rules-requires-root
Renamed-From:
 rules-does-not-require-root
Explanation: The sources can build the installation packages without using
 <code>fakeroot(1)</code> or similar.
See-Also:
 /usr/share/doc/dpkg/spec/rootless-builds.txt,
 debian-policy 4.9.2,
 debian-policy 5.6.31

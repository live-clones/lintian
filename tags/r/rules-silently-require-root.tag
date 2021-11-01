Tag: rules-silently-require-root
Severity: info
Check: debian/control/field/rules-requires-root
Renamed-From:
 should-specify-rules-requires-root
Explanation: These sources require  <code>fakeroot(1)</code> or similar to build
 the installation packages, but the field <code>Rules-Requires-Root</code> is
 empty or missing.
 .
 At least the shown path in the indicated installation package is owned by user
 (or a group) other than <code>root:root</code>.
 .
 Over time, Debian has sucessively narrowed the steps for which elevated privileges
 are required. It speeds up the building of installation packages in the archive.
 .
 Please declare whether the sources require root privileges. Eventually, Debian will
 switch the default archive-wide behaviour to expedite the build process.
 .
 You can use the field <code>Rules-Requires-Root</code> in the source stanza of
 <code>debian/control</code> to declare the required build privileges.
See-Also:
 /usr/share/doc/dpkg-dev/rootless-builds.txt.gz,
 policy 4.9.2,
 policy 5.6.31

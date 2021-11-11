Tag: silent-on-rules-requiring-root
Severity: pedantic
Check: debian/control/field/rules-requires-root
Renamed-From:
 rules-requires-root-missing
Explanation: The field <code>Rules-Requires-Root</code> is missing from the file
 <code>debian/control</code>.
 .
 Over time, Debian has sucessively narrowed the steps for which elevated privileges
 are required. It speeds up the building of installation packages in the archive.
 Eventually, Debian will switch the default archive-wide behaviour to expedite the
 build process further.
 .
 Please declare explicitly that the sources do not require root privileges. You can
 use the setting  <code>Rules-Requires-Root: no</code> in the source stanza of
 <code>debian/control</code>, but please verify with <code>diffoscope(1)</code> that
 the installation packages produced are in fact identical.
See-Also:
 /usr/share/doc/dpkg/rootless-builds.txt.gz,
 policy 4.9.2,
 policy 5.6.31

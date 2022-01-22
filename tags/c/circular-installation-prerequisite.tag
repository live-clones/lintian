Tag: circular-installation-prerequisite
Severity: warning
Check: debian/control/prerequisite/circular
Renamed-From:
 package-depends-on-itself
Explanation: The installable declares itself as its own installation prerequisite
 in the relevant <code>debian/control</code> stanza.
 .
 Current versions of <code>dpkg-gencontrol</code> will silently ignore the
 prerequisite, but it may still indicate an oversight. It could be a misspelling
 or having cut and pasted an incorrect package name.
See-Also:
 debian-policy 7.2

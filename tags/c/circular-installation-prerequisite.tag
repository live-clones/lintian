Tag: circular-installation-prerequisite
Severity: warning
Check: debian/control/prerequisite/circular
Renamed-From:
 package-depends-on-itself
Explanation: The package is its own installation prerquisite in the relevant
 <code>debian/control</code> stanza.
 .
 Current versions of <code>dpkg-gencontrol</code> will silently ignore the
 prerequisite, but this may still indicate an oversight, like a misspelling
 or having unintentionally cut and pasted an incorrect package name.
See-Also:
 policy 7.2

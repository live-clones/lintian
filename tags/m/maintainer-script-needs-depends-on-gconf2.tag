Tag: maintainer-script-needs-depends-on-gconf2
Severity: warning
Check: scripts
Explanation: This script calls gconf-schemas, which comes from the gconf2 package,
 but does not depend or pre-depend on gconf2. If you are using dh&lowbar;gconf,
 add a dependency on ${misc:Depends} and dh&lowbar;gconf will take care of this
 for you.

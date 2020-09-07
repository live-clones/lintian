Tag: maintainer-script-needs-depends-on-xml-core
Severity: warning
Check: scripts
Explanation: This script calls update-xmlcatalog, which comes from the xml-core
 package, but does not depend or pre-depend on xml-core. Packages that call
 update-xmlcatalog need to depend on xml-core. If you are using
 dh&lowbar;installxmlcatalogs, add a dependency on ${misc:Depends} and
 dh&lowbar;installxmlcatalogs will take care of this for you.

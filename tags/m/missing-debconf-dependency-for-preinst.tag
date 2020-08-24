Tag: missing-debconf-dependency-for-preinst
Severity: warning
Check: debian/debconf
Explanation: Packages using debconf in their preinst scripts must pre-depend
 on debconf.
 .
 Since debconf is usually installed already, that is better than
 depending on it but falling back to a different configuration system.

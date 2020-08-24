Tag: maintainer-script-needs-depends-on-update-inetd
Severity: warning
Check: scripts
Explanation: This script calls update-inetd, but the package does not depend or
 pre-depend on inet-superserver, any of the providers of inet-superserver
 which provide it, or update-inetd.
 .
 update-inetd has been moved from netbase into a separate package, so a
 dependency on netbase should be updated to depend on "openbsd-inetd |
 inet-superserver".

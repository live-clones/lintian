Tag: udeb-postinst-calls-ldconfig
Severity: error
Check: maintainer-scripts/ldconfig
Renamed-From:
 udeb-postinst-must-not-call-ldconfig
Explanation: The udeb invokes ldconfig via postinst on install. That is
 an error in udebs.
 .
 ldconfig is not available (and not needed) in debian-installer.

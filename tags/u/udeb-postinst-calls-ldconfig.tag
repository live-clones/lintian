Tag: udeb-postinst-calls-ldconfig
Severity: error
Check: shared-libs
Renamed-From: udeb-postinst-must-not-call-ldconfig
Explanation: The udeb invokes ldconfig on install, which is an error in udebs.
 .
 ldconfig is not available and not needed in debian-installer.
 .
 Note that this tag may (despite what the name suggests) be issued if
 the udeb uses a dpkg trigger to invoke ldconfig.

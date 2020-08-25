Tag: debian-rules-sets-DEB_BUILD_OPTIONS
Severity: warning
Check: debian/rules
See-Also: dpkg-buildflags(1)
Explanation: The <code>debian/rules</code> file sets the DEB&lowbar;BUILD&lowbar;OPTIONS variable,
 which will override any user-specified build profile.
 .
 Please replace with DEB&lowbar;BUILD&lowbar;MAINT&lowbar;OPTIONS.

Tag: debian-rules-sets-DEB_BUILD_OPTIONS
Severity: warning
Check: debian/rules
See-Also: dpkg-buildflags(1)
Explanation: The <code>debian/rules</code> file sets the DEB_BUILD_OPTIONS variable,
 which will override any user-specified build profile.
 .
 Please replace with DEB_BUILD_MAINT_OPTIONS.

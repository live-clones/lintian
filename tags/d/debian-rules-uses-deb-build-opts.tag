Tag: debian-rules-uses-deb-build-opts
Severity: warning
Check: debian/rules
Renamed-From: debian-rules-should-not-use-DEB_BUILD_OPTS
Explanation: The standard environment variable for build options is
 DEB&lowbar;BUILD&lowbar;OPTIONS. Usually, referring to DEB&lowbar;BUILD&lowbar;OPTS is a mistake and
 DEB&lowbar;BUILD&lowbar;OPTIONS was intended instead.

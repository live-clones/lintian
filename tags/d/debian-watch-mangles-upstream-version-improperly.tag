Tag: debian-watch-mangles-upstream-version-improperly
Severity: info
Check: debian/watch
Renamed-From: debian-watch-file-should-uversionmangle-not-dversionmangle
See-Also: https://wiki.debian.org/DEHS
Explanation: The version of this package contains <code>alpha</code>, <code>beta</code>,
 or <code>rc</code>, but a misleading Debian version mangling occurs in
 the <code>debian/watch</code> file. You should use the uversionmangle
 option instead of dversionmangle so that the prerelease is sorted by
 uscan before a possible future final release.

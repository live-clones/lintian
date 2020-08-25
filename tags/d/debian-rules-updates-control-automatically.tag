Tag: debian-rules-updates-control-automatically
Severity: error
Check: debian/rules
Renamed-From: debian-rules-should-not-automatically-update-control
Explanation: DEB_AUTO_UPDATE_DEBIAN_CONTROL appears to be set to <code>yes</code> in
 the <code>debian/rules</code> file. This activates a feature of CDBS which
 may not be used in packages uploaded to the Debian archive.
See-Also: https://ftp-master.debian.org/REJECT-FAQ.html

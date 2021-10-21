Tag: maintainer-script-calls-systemctl
Severity: warning
Check: maintainer-scripts/systemctl
Explanation: The maintainer script calls systemctl directly. Actions such as enabling
 a unit file should be done using <code>deb-systemd-helper</code> so that they work
 on machines with or without systemd. Starting a service should be done via
 <code>invoke-rc.d</code> if the service has a corresponding sysvinit script or
 <code>deb-systemd-invoke</code> if it does not.
 .
 If you are using debhelper, please use the <code>systemd</code> debhelper
 addon, which is provided by <code>debhelper (&gt;= 9.20160709~)</code>.
See-Also:
 https://wiki.debian.org/Teams/pkg-systemd/Packaging

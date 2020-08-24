Tag: maintainer-script-calls-systemctl
Severity: warning
Check: systemd
See-Also: https://wiki.debian.org/Teams/pkg-systemd/Packaging
Explanation: The maintainer script calls systemctl directly. Actions such as enabling
 a unit file should be done using <tt>deb-systemd-helper</tt> so that they work
 on machines with or without systemd. Starting a service should be done via
 <tt>invoke-rc.d</tt> if the service has a corresponding sysvinit script or
 <tt>deb-systemd-invoke</tt> if it does not.
 .
 If you are using debhelper, please use the <tt>systemd</tt> debhelper
 addon, which is provided by <tt>debhelper (&gt;= 9.20160709~)</tt>.

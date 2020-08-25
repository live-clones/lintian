Tag: missing-systemd-service-for-init.d-rcS-script
Severity: error
Check: systemd
See-Also: https://wiki.debian.org/Teams/pkg-systemd/rcSMigration
Explanation: The rcS init.d script has no systemd equivalent.
 .
 Systemd has a SysV init.d script compatibility mode. It provides access to
 each SysV init.d script as long as there is no native service file with the
 same name (e.g. <code>/lib/systemd/system/rsyslog.service</code> corresponds to
 <code>/etc/init.d/rsyslog</code>).
 .
 Services in rcS.d are particularly problematic, because they often cause
 dependency loops, as they are ordered very early in the boot sequence.
Renamed-From:
 systemd-no-service-for-init-rcS-script

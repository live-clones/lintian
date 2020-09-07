Tag: omitted-systemd-service-for-init.d-script
Severity: error
Check: systemd
Explanation: The specified init.d script has no systemd equivalent and the
 package ships other units.
 .
 This typically occurs when a maintainer missed script when adding
 systemd integration, or a new init script was added in a new upstream
 version.
 .
 Systemd has a SysV init.d script compatibility mode. It provides access to
 each SysV init.d script as long as there is no native service file with the
 same name (e.g. <code>/lib/systemd/system/rsyslog.service</code> corresponds to
 <code>/etc/init.d/rsyslog</code>).
Renamed-From:
 systemd-no-service-for-init-script

Tag: systemd-service-file-refers-to-var-run
Severity: info
Check: systemd
Explanation: The specified systemd service file declares a <code>PIDFile=</code>
 that references <code>/var/run</code>.
 .
 <code>/var/run</code> is now merely a symlink pointing to <code>/run</code> and
 thus it is now considered best practice that packages use <code>/run</code>
 directly.
 .
 Please update the specified service file.
Renamed-From:
 systemd-service-file-pidfile-refers-to-var-run

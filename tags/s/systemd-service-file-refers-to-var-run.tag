Tag: systemd-service-file-refers-to-var-run
Severity: info
Check: systemd
Explanation: The specified systemd service file declares a <tt>PIDFile=</tt>
 that references <tt>/var/run</tt>.
 .
 <tt>/var/run</tt> is now merely a symlink pointing to <tt>/run</tt> and
 thus it is now considered best practice that packages use <tt>/run</tt>
 directly.
 .
 Please update the specified service file.
Renamed-From:
 systemd-service-file-pidfile-refers-to-var-run

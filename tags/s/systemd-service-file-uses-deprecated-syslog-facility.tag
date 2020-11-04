Tag: systemd-service-file-uses-deprecated-syslog-facility
Severity: warning
Check: systemd
Explanation: The specified systemd service file specifies
 <code>StandardOutput=</code> or <code>StandardError=</code> that references
 <code>syslog</code> or <code>syslog-console</code>.
 .
 This is discouraged, and systemd versions 246 and above will log a
 warning about this.
See-Also:
 https://github.com/systemd/systemd/blob/6706384a89ae0c462e7172588c80667190c4d9e2/NEWS#L724

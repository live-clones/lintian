Tag: systemd-service-file-uses-nobody-or-nogroup
Severity: warning
Check: systemd
Explanation: The specified systemd service file declares a <code>User=</code>
 or <code>Group=</code> that references <code>nobody</code> or <code>nogroup</code>.
 .
 This is discouraged, and systemd versions 246 and above will log a
 warning about this.
See-Also: https://github.com/systemd/systemd/blob/master/NEWS#L106

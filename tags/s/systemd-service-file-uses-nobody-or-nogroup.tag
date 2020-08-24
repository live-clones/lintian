Tag: systemd-service-file-uses-nobody-or-nogroup
Severity: warning
Check: systemd
Explanation: The specified systemd service file declares a <tt>User=</tt>
 or <tt>Group=</tt> that references <tt>nobody</tt> or <tt>nogroup</tt>.
 .
 This is discouraged, and systemd versions 246 and above will log a
 warning about this.
See-Also: https://github.com/systemd/systemd/blob/master/NEWS#L106

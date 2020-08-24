Tag: systemd-service-file-uses-deprecated-syslog-facility
Severity: warning
Check: systemd
Explanation: The specified systemd service file specifies
 <tt>StandardOutput=</tt> or <tt>StandardError=</tt> that references
 <tt>syslog</tt> or <tt>syslog-console</tt>.
 .
 This is discouraged, and systemd versions 246 and above will log a
 warning about this.
See-Also: https://github.com/systemd/systemd/blob/master/NEWS#L101

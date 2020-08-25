Tag: systemd-service-file-refers-to-obsolete-target
Severity: warning
Check: systemd
Explanation: The systemd service file refers to an obsolete target.
 .
 Some targets are obsolete by now, e.g. syslog.target or dbus.target. For
 example, declaring <code>After=syslog.target</code> is unnecessary by now because
 syslog is socket-activated and will therefore be started when needed.

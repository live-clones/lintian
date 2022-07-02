Tag: kill-mode-none
Severity: warning
Check: systemd
Explanation: The named systemd unit is configured to use <code>KillMode=none</code>.
 That is unsafe because it disables systemd's process lifecycle management for the
 service.
 .
 Please update your service to use a safer <code>KillMode</code>, such as
 <code>mixed</code> or <code>control-group</code>.
 .
 Support for <code>KillMode=none</code> is deprecated and will eventually be removed.
See-also:
 systemd.kill(5)

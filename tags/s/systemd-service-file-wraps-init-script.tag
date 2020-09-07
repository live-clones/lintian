Tag: systemd-service-file-wraps-init-script
Severity: warning
Check: systemd
Explanation: The listed service file simply uses ths existing SysV init script
 via ExecStart, ExecStop, etc.
 .
 The main logic of more complex init scripts should be moved into helper
 scripts which can be used directly from both the .service file and the
 init script. This will also make the init scripts more readable and easier
 to support other alternatives. Note that as /etc/init.d/&ast; files are
 conffiles, such updates are not guaranteed to reach users.

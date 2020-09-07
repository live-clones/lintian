Tag: bad-permissions-for-etc-cron.d-script
Severity: error
Check: cron
Explanation: Files in <code>/etc/cron.d</code> are configuration files for cron and not
 scripts. Thus, they should not be marked executable.

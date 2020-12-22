Tag: init.d-script-possible-missing-stop
Severity: warning
Check: init-d
Explanation: The given <code>/etc/init.d</code> script indicates it should be
 stopped at one of the runlevels 0, 1, or 6 but not at all of them.
 This is usually a mistake. Normally, facilities that need to be stopped
 at any of those runlevels need to be stopped at all of them.
 .
 For example, if it is safe for the facility provided by this init script
 to be stopped by <code>sendsigs</code> at runlevels 0 and 6, there should be
 no reason to special case runlevel 1, where <code>killprocs</code> would
 stop it. If the facility needs special shutdown handling when rebooting
 the system (runlevel 6), it probably needs the same handling when
 halting the system (runlevel 0) or switching to single-user mode
 (runlevel 1).

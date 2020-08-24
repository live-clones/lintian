Tag: maintainer-script-calls-start-stop-daemon
Severity: warning
Check: scripts
Renamed-From: maintainer-script-should-not-use-start-stop-daemon
Explanation: The maintainer script seems to call <tt>start-stop-daemon</tt>
 directly. Long-running daemons should be started and stopped via init
 scripts using <tt>invoke-rc.d</tt> rather than directly in maintainer
 scripts.
See-Also: policy 9.3.3.2

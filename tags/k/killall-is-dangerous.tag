Tag: killall-is-dangerous
Severity: warning
Check: maintainer-scripts/killall
Explanation: The maintainer script seems to call <code>killall</code>. Since the
 program terminates processes by name, it may accidentally affect unrelated
 processes.
 .
 Most uses of <code>killall</code> should use <code>invoke-rc.d</code>
 instead.

Tag: killall-is-dangerous
Severity: warning
Check: scripts
Explanation: The maintainer script seems to call <code>killall</code>. Since this
 utility kills processes by name, it may well end up killing unrelated
 processes. Most uses of <code>killall</code> should use <code>invoke-rc.d</code>
 instead.

Tag: killall-is-dangerous
Severity: warning
Check: scripts
Explanation: The maintainer script seems to call <tt>killall</tt>. Since this
 utility kills processes by name, it may well end up killing unrelated
 processes. Most uses of <tt>killall</tt> should use <tt>invoke-rc.d</tt>
 instead.

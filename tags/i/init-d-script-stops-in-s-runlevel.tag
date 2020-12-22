Tag: init-d-script-stops-in-s-runlevel
Severity: warning
Check: init-d
Explanation: This <code>/etc/init.d</code> script specifies the S runlevel in
 Default-Stop in its LSB keyword section. The S runlevel is not a real
 runlevel and is only used during boot. There is no way to switch to it
 and hence no use for stop scripts for it, so S should be removed from
 Default-Stop.

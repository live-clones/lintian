Tag: init.d-script-has-unterminated-lsb-section
Severity: error
Check: init-d
See-Also: https://wiki.debian.org/LSBInitScripts
Explanation: This <code>/etc/init.d</code> script has an LSB keyword section starting
 with <code>### BEGIN INIT INFO</code> but either has no matching <code>### END
 INIT INFO</code> or has lines between those two markers that are not
 comments. The line number given is the first line that doesn't look like
 part of an LSB keyword section. There must be an end marker after all
 the keyword settings and there must not be any lines between those
 markers that do not begin with <code>#</code>.

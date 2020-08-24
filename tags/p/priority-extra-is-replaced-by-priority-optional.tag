Tag: priority-extra-is-replaced-by-priority-optional
Severity: warning
Check: fields/priority
Explanation: Since Debian Policy version 4.0.1, the priority <tt>extra</tt>
 has been deprecated.
 .
 Please update <tt>debian/control</tt> and replace all instances of
 <tt>Priority: extra</tt> with <tt>Priority: optional</tt>.
See-Also: policy 2.5

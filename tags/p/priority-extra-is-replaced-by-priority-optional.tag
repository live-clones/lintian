Tag: priority-extra-is-replaced-by-priority-optional
Severity: warning
Check: fields/priority
Explanation: Since Debian Policy version 4.0.1, the priority <code>extra</code>
 has been deprecated.
 .
 Please update <code>debian/control</code> and replace all instances of
 <code>Priority: extra</code> with <code>Priority: optional</code>.
See-Also: policy 2.5

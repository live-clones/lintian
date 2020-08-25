Tag: excessive-priority-for-library-package
Severity: warning
Check: fields/priority
Explanation: The given package appears to be a library package, but it has "Priority"
 of "required", "important", or "standard".
 .
 In general, a library package should only get pulled in on a system because
 some other package depends on it; no library package needs installation on a
 system where nothing uses it.
 .
 Please update <code>debian/control</code> and downgrade the severity to, for
 example, <code>Priority: optional</code>.

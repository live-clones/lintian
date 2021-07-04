Tag: manual-page-for-system-command
Check: documentation/manual
Severity: pedantic
Renamed-From: command-in-sbin-has-manpage-in-incorrect-section
Explanation: The command in <code>/sbin</code> or <code>/usr/sbin</code> are system
 administration commands; their manual pages thus belong in section 8,
 not section 1.
 .
 Please check whether the command is actually useful to non-privileged
 user in which case it should be moved to <code>/bin</code> or
 <code>/usr/bin</code>, or alternatively the manual page should be moved to
 section 8 instead, ie. <code>/usr/share/man/man8</code>.
See-Also:
 Bug#348864,
 Bug#253011,
 hier(7)

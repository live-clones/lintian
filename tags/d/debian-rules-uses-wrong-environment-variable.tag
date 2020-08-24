Tag: debian-rules-uses-wrong-environment-variable
Severity: warning
Check: debian/rules
Renamed-From: debian-rules-should-not-use-or-modify-user-only-variable
See-Also: #631786
Explanation: The rules file appears to be reading or modifying a variable not
 intended for use by package maintainers.
 .
 The special variables <tt>DEB_*FLAGS_{SET,APPEND}</tt> can be used by
 users who want to re-compile Debian packages with special (or
 non-standard) build flags.
 .
 Please use the <tt>DEB_*FLAGS_MAINT_{SET,APPEND}</tt> flags instead.

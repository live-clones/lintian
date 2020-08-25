Tag: debian-rules-uses-wrong-environment-variable
Severity: warning
Check: debian/rules
Renamed-From: debian-rules-should-not-use-or-modify-user-only-variable
See-Also: Bug#631786
Explanation: The rules file appears to be reading or modifying a variable not
 intended for use by package maintainers.
 .
 The special variables <code>DEB&lowbar;&ast;FLAGS&lowbar;{SET,APPEND}</code> can be used by
 users who want to re-compile Debian packages with special (or
 non-standard) build flags.
 .
 Please use the <code>DEB&lowbar;&ast;FLAGS&lowbar;MAINT&lowbar;{SET,APPEND}</code> flags instead.

Tag: package-depends-on-hardcoded-libc
Severity: warning
Check: substvars/libc
Explanation: The package depends directly on <code>libc</code>. Please use
 only the substitution variables <code>${shlibs:Depends}</code> in the relevant
 stanza in the <code>debian/control</code> file.

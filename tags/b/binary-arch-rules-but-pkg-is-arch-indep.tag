Tag: binary-arch-rules-but-pkg-is-arch-indep
Severity: warning
Check: debian/rules
Explanation: It looks like you try to run code in the binary-arch target of 
 <code>debian/rules</code>, even though your package is architecture-
 independent.

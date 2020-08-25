Tag: useless-autoreconf-build-depends
Severity: warning
Check: debhelper
Explanation: Since compatibility level 10, debhelper enables the <code>autoreconf</code>
 sequence by default.
 .
 It is therefore not necessary to specify build-dependencies on
 <code>dh-autoreconf</code> or <code>autotools-dev</code> and they can be removed.

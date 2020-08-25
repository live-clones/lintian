Tag: depends-on-misc-pre-depends
Severity: warning
Check: debian/control
Explanation: This package has a <code>Depends</code> field that contains the
 <code>${misc:Pre-Depends}</code> substitution variable. This should be in
 the <code>Pre-Depends</code> field instead.

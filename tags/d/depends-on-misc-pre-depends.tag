Tag: depends-on-misc-pre-depends
Severity: warning
Check: debian/control
Explanation: This package has a <tt>Depends</tt> field that contains the
 <tt>${misc:Pre-Depends}</tt> substitution variable. This should be in
 the <tt>Pre-Depends</tt> field instead.

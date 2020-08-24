Tag: prerm-has-useless-call-to-install-docs
Severity: warning
Check: menus
Explanation: Explicitly calling <tt>install-docs</tt> in <tt>prerm</tt> is no
 longer required since doc-base file processing is handled by triggers.
 If the <tt>install-docs</tt> call was added by debhelper, rebuilding the
 package with debhelper 7.2.3 or later will fix this problem.

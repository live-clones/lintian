Tag: prerm-has-useless-call-to-install-docs
Severity: warning
Check: menus
Explanation: Explicitly calling <code>install-docs</code> in <code>prerm</code> is no
 longer required since doc-base file processing is handled by triggers.
 If the <code>install-docs</code> call was added by debhelper, rebuilding the
 package with debhelper 7.2.3 or later will fix this problem.

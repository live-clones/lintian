Tag: postinst-has-useless-call-to-install-docs
Severity: warning
Check: menus
Explanation: It is no longer necessary to call <code>install-docs</code>
 in <code>postinst</code>. The processing of <code>doc-base</code> files is
 now handled by triggers.
 .
 If the <code>install-docs</code> call was added by Debhelper, the issue can
 be fixed by rebuilding the package with Debhelper version 7.2.3 or later.

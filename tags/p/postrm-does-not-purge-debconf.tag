Tag: postrm-does-not-purge-debconf
Severity: warning
Check: debian/debconf
Explanation: Packages using debconf should call <code>db&lowbar;purge</code> or its equivalent
 in their postrm. If the package uses debhelper, dh&lowbar;installdebconf(1) should
 take care of this.

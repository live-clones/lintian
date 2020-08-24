Tag: debian-rules-uses-deprecated-systemd-override
Severity: error
Check: debhelper
Explanation: The <tt>debian/rules</tt> file for this package has an
 <tt>override_dh_systemd_enable</tt> or <tt>override_dh_systemd_start</tt>
 target but the package uses debhelper compatibility level 11.
 .
 The <tt>dh_systemd_{enable,start}</tt> commands were deprecated in this
 compat level and are no longer called. This is likely to cause your
 package to not function as intended.
 .
 Please replace these with calls to <tt>dh_installsystemd</tt>.
See-Also: debhelper(7)

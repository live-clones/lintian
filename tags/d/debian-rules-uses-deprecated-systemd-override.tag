Tag: debian-rules-uses-deprecated-systemd-override
Severity: error
Check: debhelper
Explanation: The <code>debian/rules</code> file for this package has an
 <code>override_dh_systemd_enable</code> or <code>override_dh_systemd_start</code>
 target but the package uses debhelper compatibility level 11.
 .
 The <code>dh_systemd_{enable,start}</code> commands were deprecated in this
 compat level and are no longer called. This is likely to cause your
 package to not function as intended.
 .
 Please replace these with calls to <code>dh_installsystemd</code>.
See-Also: debhelper(7)

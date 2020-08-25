Tag: debian-rules-uses-deprecated-systemd-override
Severity: error
Check: debhelper
Explanation: The <code>debian/rules</code> file for this package has an
 <code>override&lowbar;dh&lowbar;systemd&lowbar;enable</code> or
 <code>override&lowbar;dh&lowbar;systemd&lowbar;start</code>
 target but the package uses debhelper compatibility level 11.
 .
 The <code>dh&lowbar;systemd&lowbar;{enable,start}</code> commands were deprecated in this
 compat level and are no longer called. This is likely to cause your
 package to not function as intended.
 .
 Please replace these with calls to <code>dh&lowbar;installsystemd</code>.
See-Also: debhelper(7)

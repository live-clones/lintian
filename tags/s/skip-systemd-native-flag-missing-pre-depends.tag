Tag: skip-systemd-native-flag-missing-pre-depends
Severity: warning
Check: systemd/native/prerequisites
Explanation: The named maintainer script uses the <code>--skip-systemd-native</code>
 option to <code>invoke-rc.d</code> but does not declare a <code>Pre-Depends</code>
 prerequisite on <code>init-system-helpers</code>.
 .
 The flag helps to defer <code>systemd</code> actions until
 <code>deb-systemd-invoke(1p)</code> is called.
 .
 Please add <code>Pre-Depends: ${misc:Pre-Depends}</code> to your
 <code>debian/control</code> file.
See-Also:
 invoke-rc.d(8),
 deb-systemd-invoke(1p)

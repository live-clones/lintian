Tag: skip-systemd-native-flag-missing-pre-depends
Severity: warning
Check: scripts
See-Also: invoke-rc.d(8), deb-systemd-invoke(1p)
Explanation: This package uses the <code>--skip-systemd-native</code>
 <code>invoke-rc.d</code> flag in the specified maintainer script but does
 not specify a <code>Pre-Depends</code> dependency on a recent version of
 <code>init-system-helpers</code>.
 .
 This flag is useful for maintainer scripts that want to defer systemd
 actions to <code>deb-systemd-invoke(1p)</code>. However, it was only added
 in <code>init-system-helpers</code> version 1.58.
 .
 Please add <code>Pre-Depends: ${misc:Pre-Depends}</code> to your
 <code>debian/control</code> file.

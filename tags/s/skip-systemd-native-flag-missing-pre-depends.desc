Tag: skip-systemd-native-flag-missing-pre-depends
Severity: warning
Check: scripts
See-Also: invoke-rc.d(8), deb-systemd-invoke(1p)
Explanation: This package uses the <tt>--skip-systemd-native</tt>
 <tt>invoke-rc.d</tt> flag in the specified maintainer script but does
 not specify a <tt>Pre-Depends</tt> dependency on a recent version of
 <tt>init-system-helpers</tt>.
 .
 This flag is useful for maintainer scripts that want to defer systemd
 actions to <tt>deb-systemd-invoke(1p)</tt>. However, it was only added
 in <tt>init-system-helpers</tt> version 1.58.
 .
 Please add <tt>Pre-Depends: ${misc:Pre-Depends}</tt> to your
 <tt>debian/control</tt> file.

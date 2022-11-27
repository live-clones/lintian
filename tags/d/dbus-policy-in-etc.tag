Tag: dbus-policy-in-etc
Severity: warning
Check: desktop/dbus
Explanation: The package contains D-Bus policy configuration and installs it
 under <code>/etc/dbus-1/system.d</code> or
 <code>/etc/dbus-1/session.d</code>. These directories are reserved for
 local configuration, which overrides the default policies in
 <code>/usr</code>.
 .
 The correct directory for system bus policy installed by packages is
 <code>/usr/share/dbus-1/system.d</code>.
 .
 The correct directory for session bus policy installed by packages
 (not usually needed) is <code>/usr/share/dbus-1/session.d</code>.
See-Also:
 dbus-daemon(1)

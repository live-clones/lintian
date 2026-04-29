Tag: dh-install-instead-of-dh-installmodules
Severity: info
Check: modprobe
Explanation: This package installs a Debian-specific <code>.conf</code>
 file into a <code>modprobe.d</code> directory manually via
 <code>dh_install</code>.
 .
 Please rename this file to follow the <code>debian/package.modprobe</code>
 naming convention in order to have <code>dh_installmodules</code>
 automatically install it instead.
See-Also: dh_installmodule (1)

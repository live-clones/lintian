Tag: dh-install-instead-of-dh-installmodules
Severity: info
Check: modprobe
Explanation: This package is installing a Debian-specific <code>.conf</code>
 file into a <code>modprobe.d</code> directory manually via
 <code>dh_install</code>. Consider renaming the file to have the
 <code>.modprobe</code> suffix to let <code>dh_installmodules</code>
 automatically install it correctly.

Tag: systemd-service-file-outside-lib
Severity: error
Check: systemd
Explanation: The package ships a systemd service file outside
 <tt>/lib/systemd/system/</tt>
 .
 Systemd in Debian searches for unit files in <tt>/lib/systemd/system/</tt>
 and <tt>/etc/systemd/system</tt>. Notably, it does <i>not</i> look
 in <tt>/usr/lib/systemd/system/</tt> for service files.
 .
 System administrators should have the possibility to overwrite a
 service file (or parts of it, in newer systemd versions) by placing a
 file in <tt>/etc/systemd/system</tt>, so the canonical location used
 for service files is <tt>/lib/systemd/system/</tt>.

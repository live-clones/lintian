Tag: systemd-service-file-outside-lib
Severity: error
Check: systemd
Explanation: The package ships a systemd service file outside
 <code>/lib/systemd/system/</code>
 .
 Systemd in Debian searches for unit files in <code>/lib/systemd/system/</code>
 and <code>/etc/systemd/system</code>. Notably, it does *not* look
 in <code>/usr/lib/systemd/system/</code> for service files.
 .
 System administrators should have the possibility to overwrite a
 service file (or parts of it, in newer systemd versions) by placing a
 file in <code>/etc/systemd/system</code>, so the canonical location used
 for service files is <code>/lib/systemd/system/</code>.

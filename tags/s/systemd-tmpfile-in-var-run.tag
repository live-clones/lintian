Tag: systemd-tmpfile-in-var-run
Severity: info
Check: systemd/tmpfiles
Explanation: The named systemd file declares a temporary file with a location
 in <code>/var/run</code>.
 .
 <code>/var/run</code> is nowadays a just symbolic link to <code>/run</code>.
 Packages should use <code>/run</code> instead.
 .
 Please update the named file.
See-Also:
 Bug#984678

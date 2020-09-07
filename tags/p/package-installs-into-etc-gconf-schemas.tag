Tag: package-installs-into-etc-gconf-schemas
Severity: warning
Check: desktop/gnome
Explanation: The package installs files into the <code>/etc/gconf/schemas</code>
 directory. No package should do this; this directory is reserved for
 local overrides. Instead, schemas should be installed into
 <code>/usr/share/gconf/schemas</code>.

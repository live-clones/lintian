Tag: debian-control-file-is-a-symlink
Severity: warning
Check: debian/control
Explanation: The <code>debian/control</code> file is a symlink rather than a regular
 file. Using symlinks for required source package files is unnecessary and
 makes package checking and manipulation more difficult. If the control
 file should be available in the source package under multiple names, make
 <code>debian/control</code> the real file and the other names symlinks to it.

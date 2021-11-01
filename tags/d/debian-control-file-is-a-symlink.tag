Tag: debian-control-file-is-a-symlink
Severity: warning
Check: debian/control/link
Explanation: The <code>debian/control</code> file is a symbolic link.
 .
 It is not recommended to use anything other than plain files for the required
 source files. Using links makes it harder to check and manipulate sources
 automatically.
 .
 If the file must be available under multiple names, please make
 <code>debian/control</code> the real file and let the other names point to it.

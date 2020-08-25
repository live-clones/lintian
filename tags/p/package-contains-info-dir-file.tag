Tag: package-contains-info-dir-file
Severity: error
Check: documentation
Explanation: This package contains a file named <code>dir</code> or <code>dir.old</code>,
 possibly compressed, in <code>/usr/share/info</code>. This is the directory
 (or backup) of info pages and is generated automatically by install-info
 when a package containing info documentation is installed. Some upstream
 build systems create it automatically, but it must not be included in a
 package since it needs to be generated dynamically based on the installed
 info files on the system.

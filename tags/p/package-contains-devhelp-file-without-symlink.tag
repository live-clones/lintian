Tag: package-contains-devhelp-file-without-symlink
Severity: warning
Check: files/devhelp
Explanation: This package contains a &ast;.devhelp or &ast;.devhelp2 file which is not in
 the devhelp search path (<code>/usr/share/devhelp/books</code> and
 <code>/usr/share/gtk-doc/html</code>) and is apparently not in a directory
 linked into the devhelp search path. This will prevent devhelp from
 finding the documentation.
 .
 If the devhelp documentation is installed in a path outside the devhelp
 search path (such as <code>/usr/share/doc</code>), create a symlink in
 <code>/usr/share/gtk-doc/html</code> pointing to the documentation directory.

Tag: unwanted-path-too-specific
Severity: warning
Check: debian/not-installed
Explanation: The file <code>debian/not-installed</code> lists a path that may
 cause unexpected build failures. The path is too specific.
 .
 A common problem are entries starting with
 <code>usr/lib/x86&lowbar;64-linux-gnu</code>. The sources will build fine
 on <code>amd64</code> but not on other architectures, because the
 paths to do exist.
 .
 Please consider using an asterisk, which will work fine.
See-Also: Bug#961104, Bug#961960, Bug#961973

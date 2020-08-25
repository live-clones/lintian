Tag: no-manual-page
Severity: warning
Check: documentation/manual
Renamed-From: binary-without-manpage
Explanation: Each binary in <code>/usr/bin</code>, <code>/usr/sbin</code>, <code>/bin</code>,
 <code>/sbin</code> or <code>/usr/games</code> should have a manual page
 .
 Note that though the <code>man</code> program has the capability to check for
 several program names in the NAMES section, each of these programs
 should have its own manual page (a symbolic link to the appropriate
 manual page is sufficient) because other manual page viewers such as
 xman or tkman don't support this.
 .
 If the name of the manual page differs from the binary by case, <code>man</code>
 may be able to find it anyway; however, it is still best practice to match
 the exact capitalization of the executable in the manual page.
 .
 If the manual pages are provided by another package on which this package
 depends, Lintian may not be able to determine that manual pages are
 available. In this case, after confirming that all binaries do have
 manual pages after this package and its dependencies are installed, please
 add a Lintian override.
See-Also: policy 12.1

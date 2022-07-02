Tag: absolute-symlink-in-top-level-folder
Severity: warning
Check: files/symbolic-links
Renamed-From: symlink-should-be-relative
Explanation: Symbolic links to files in the same top-level directory should be
 relative.
 .
 As an example, a link in <code>/usr</code> to another file in <code>/usr</code>
 should be relative, while a link in <code>/usr</code> to a file in
 <code>/etc</code> should be absolute.
 .
 With Debhelper, running dh&lowbar;link after creating the package structure
 will fix the issue for you.
See-Also:
 debian-policy 10.5

Tag: absolute-symlink-in-top-level-folder
Severity: warning
Check: files/symbolic-links
Renamed-From: symlink-should-be-relative
Explanation: Symlinks to files which are in the same top-level directory should be
 relative according to policy. (In other words, a link in /usr to another
 file in /usr should be relative, while a link in /usr to a file in /etc
 should be absolute.)
 .
 If you use debhelper, running dh&lowbar;link after creating the package structure
 will fix this problem for you.
See-Also: policy 10.5

Tag: relative-symlink
Severity: error
Check: files/symbolic-links
Renamed-From: symlink-should-be-absolute
Explanation: Symbolic links between different top-level directories should be
 absolute.
 .
 If you use debhelper, running dh&lowbar;link after creating the package structure
 will fix this problem for you.
See-Also: policy 10.5

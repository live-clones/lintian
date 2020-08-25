Tag: symlink-contains-spurious-segments
Severity: error
Check: files/symbolic-links
Explanation: The symbolic link has needless segments like ".." and "." in the
 middle. These are unneeded and make the link longer than it could be,
 which is in violation of policy. They can also cause problems in the
 presence of symlinked directories.
 .
 If you use debhelper, running dh&lowbar;link after creating the package structure
 will fix this problem for you.
See-Also: policy 10.5

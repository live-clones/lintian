Tag: symlink-ends-with-slash
Severity: warning
Check: files/symbolic-links
Explanation: This symlink ends with a slash (/). This is in violation
 of policy, where it is stated that symlinks should be as short as possible
 .
 If you use debhelper, running dh&lowbar;link after creating the package structure
 will fix this problem for you.
See-Also: policy 10.5

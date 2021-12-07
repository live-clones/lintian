Tag: symlink-ends-with-slash
Severity: warning
Check: files/symbolic-links
Explanation: This symbolic link target ends with a slash (/). That geos against
 Debian policy, which states that symbolic links should be as short as possible.
 .
 With Debhelper, running dh&lowbar;link after creating the package structure
 will fix this problem for you.
See-Also:
 debian-policy 10.5

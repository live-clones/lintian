Tag: symlink-contains-spurious-segments
Severity: error
Check: files/symbolic-links
Explanation: The symbolic link target contains superfluous path segments like
 <code>..</code> or <code>.</code>. They are not needed and make the link longer
 than necessary, which goes against Debian policy.
 .
 Such segments can also cause unexpected problems in the presence of symlinked
 directories.
 .
 With Debhelper, running dh&lowbar;link after creating the package structure
 will fix this problem for you.
See-Also:
 debian-policy 10.5

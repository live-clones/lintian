Tag: lengthy-symlink
Severity: error
Check: files/symbolic-links
Explanation: This link goes up, and then back down into the same subdirectory.
 Making it shorter will improve its chances of finding the right file
 if the user's system has lots of symlinked directories.
 .
 If you use debhelper, running dh&lowbar;link after creating the package structure
 will fix this problem for you.
See-Also: policy 10.5

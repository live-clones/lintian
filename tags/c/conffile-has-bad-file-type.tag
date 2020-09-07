Tag: conffile-has-bad-file-type
Severity: error
Check: conffiles
See-Also: Bug#690051, Bug#690910
Explanation: The conffiles lists this path, which is not a file. This will
 almost certainly not work.
 .
 Note that dpkg does not support symlinks being conffiles.

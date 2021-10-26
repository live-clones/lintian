Tag: possibly-insecure-handling-of-tmp-files-in-maintainer-script
Severity: warning
Check: maintainer-scripts/temporary-files
Explanation: The named maintainer script appears to access a file or a directory in
 <code>/tmp</code> or a similar folder for temporary data. Working directly in such
 folders, which are usually world-writable, can easily lead to serious security or
 privacy bugs.
 .
 Please consider using the <code>mktemp</code> utility from the <code>coreutils</code>
 package when creating temporary files or directories.
See-Also:
 policy 10.4

Tag: possibly-insecure-handling-of-tmp-files-in-maintainer-script
Severity: warning
Check: scripts
Explanation: The maintainer script seems to access a file in <code>/tmp</code> or
 some other temporary directory. Since creating temporary files in a
 world-writable directory is very dangerous, this is likely to be a
 security bug. Use the <code>tempfile</code> or <code>mktemp</code> utilities to
 create temporary files in these directories.
See-Also: policy 10.4

Tag: source-contains-svn-control-dir
Severity: pedantic
Check: cruft
Explanation: The upstream source contains an .svn directory. It was most likely
 included by accident since Subversion version control directories
 usually don't belong in releases. When packaging a Subversion snapshot,
 export from Subversion rather than checkout. If an upstream release
 tarball contains .svn directories, this should be reported as a bug to
 upstream since it can double the size of the tarball to no purpose.

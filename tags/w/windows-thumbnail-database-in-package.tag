Tag: windows-thumbnail-database-in-package
Severity: warning
Check: foreign-operating-systems
Explanation: There is a file in the package named <code>Thumbs.db</code> or
 <code>Thumbs.db.gz</code>, which is normally a Windows image thumbnail
 database. Such databases are generally useless in Debian packages and
 were usually accidentally included by copying complete directories from
 the source tarball.

Tag: debian-adds-cvs-conflict-copy
Severity: warning
Check: files/artifact
Renamed-From:
 diff-contains-cvs-conflict-copy
Explanation: The Debian diff or native package contains a CVS conflict copy.
 These have file names like <code>.#file.version</code> and are generated by
 CVS when a conflict was detected when merging local changes with updates
 from a source repository. They're useful only while resolving the
 conflict and should not be included in the package.

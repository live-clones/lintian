Tag: patch-modifying-debian-files
Severity: error
Check: debian/patches/quilt
Explanation: A patch stored in <code>debian/patches/</code> modifies or creates files
 in the <code>debian</code> folder, but that folder is already under the
 maintainer's exclusive control.
 .
 It may be more appropriate to patch or create files in the upstream
 directory hierarchy, but often it is easier to place a copy in the
 <code>debian</code> folder.

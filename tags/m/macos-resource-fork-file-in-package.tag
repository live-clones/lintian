Tag: macos-resource-fork-file-in-package
Severity: warning
Check: foreign-operating-systems
Explanation: There is a file in the package with a name starting with
 <code>.&lowbar;</code>, the file name pattern used by Mac OS X to store resource
 forks in non-native file systems. Such files are generally useless in
 Debian packages and were usually accidentally included by copying
 complete directories from the source tarball.

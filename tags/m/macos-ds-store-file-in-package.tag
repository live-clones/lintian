Tag: macos-ds-store-file-in-package
Severity: warning
Check: foreign-operating-systems
Explanation: There is a file in the package named <code>.DS&lowbar;Store</code> or
 <code>.DS&lowbar;Store.gz</code>, the file name used by Mac OS X to store folder
 attributes. Such files are generally useless in Debian packages and were
 usually accidentally included by copying complete directories from the
 source tarball.

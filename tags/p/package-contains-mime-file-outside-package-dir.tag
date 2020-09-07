Tag: package-contains-mime-file-outside-package-dir
Severity: error
Check: mimeinfo
See-Also: Bug#761649, /usr/share/doc/shared-mime-info/
Explanation: This package contains a file in a path reserved solely for
 mime cache file.
 .
 /usr/share/mime/ files are cache generated from
 /usr/share/mime/packages/. Thus file under /usr/share/mime/
 should not be installed

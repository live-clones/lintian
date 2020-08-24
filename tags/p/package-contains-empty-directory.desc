Tag: package-contains-empty-directory
Severity: info
Check: files/empty-directories
Explanation: This package installs an empty directory. This might be intentional
 but it's normally a mistake. If it is intentional, add a Lintian override.
 .
 If a package ships with or installs empty directories, you can remove them
 in debian/rules by calling:
 .
  $ find path/to/base/dir -type d -empty -delete

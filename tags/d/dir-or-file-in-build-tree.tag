Tag: dir-or-file-in-build-tree
Severity: error
Check: files/build-path
Explanation: The package installs a file in common build paths.
 .
 This often occurs if the package uses regular expressions to
 strip the build path without properly regex quoting the build
 path.

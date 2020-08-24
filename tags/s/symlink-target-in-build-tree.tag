Tag: symlink-target-in-build-tree
Severity: error
Check: files/symbolic-links
Explanation: The package sets a link with a target pointing to common
 build paths.
 .
 This often occurs if the package uses regular expressions to
 strip the build path without properly regex quoting the build
 path.

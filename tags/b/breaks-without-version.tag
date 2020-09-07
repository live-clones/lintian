Tag: breaks-without-version
Severity: warning
Check: fields/package-relations
See-Also: policy 7.3, policy 7.4, Bug#605744
Explanation: This package declares a Breaks relationship with another package
 that has no version number. Normally, Breaks should be used to indicate
 an incompatibility with a specific version of another package, or with
 all versions predating a fix. If the two packages can never be installed
 at the same time, Conflicts should normally be used instead.
 .
 Note this tag can also be issued if a package has been split into two
 completely new ones. In this case, this package is missing a Replaces
 on the old package.

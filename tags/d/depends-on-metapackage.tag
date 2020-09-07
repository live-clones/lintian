Tag: depends-on-metapackage
Severity: error
Check: fields/package-relations
Explanation: This package is one of the packages that Lintian believes is a
 metapackage: a package that exists for the convenience of users or
 installers to install a set of related packages. Packages that are not
 themselves metapackages must not depend on metapackages, since this may
 prevent the user from removing portions of the package set they don't
 need.

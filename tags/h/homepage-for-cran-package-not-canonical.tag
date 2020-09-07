Tag: homepage-for-cran-package-not-canonical
Severity: info
Check: fields/homepage
Explanation: The Homepage field for this package points to an uncanonical CRAN URL.
 Please update to use the current canonical URL instead. The canonical URL is
 recommended for use in publications, etc., will always redirect to current
 release version (or devel if package is not in release yet). For example, the
 link for the package "foo" should be:
 .
  https://cran.r-project.org/package=foo
 .
 not:
 .
  https://cran.r-project.org/web/packages/foo/index.html

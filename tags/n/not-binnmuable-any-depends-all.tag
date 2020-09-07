Tag: not-binnmuable-any-depends-all
Severity: error
Check: debian/version-substvars
Explanation: The package is not safely binNMUable because an arch:any package
 depends on an arch:all package with a (= ${binary:Version})
 relationship. Please use (= ${source:Version}) instead.
 .
 Note this is also triggered if the dependency uses (&gt;= ${var}),
 since that has the same issue.

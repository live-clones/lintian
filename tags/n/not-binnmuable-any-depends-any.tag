Tag: not-binnmuable-any-depends-any
Severity: error
Check: debian/version-substvars
Explanation: The package is not safely binNMUable because an arch:any package
 depends on another arch:any package with a (= ${source:Version})
 relationship. Please use (= ${binary:Version}) instead.

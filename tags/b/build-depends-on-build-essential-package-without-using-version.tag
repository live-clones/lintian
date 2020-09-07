Tag: build-depends-on-build-essential-package-without-using-version
Severity: error
Check: fields/package-relations
See-Also: policy 4.2
Explanation: The package declares a build-depends on a build essential package
 without using a versioned depends. Packages do not have to depend on any
 package included in build-essential. It is the responsibility of anyone
 building packages to have all build-essential packages installed. The
 only reason for an explicit dependency on a package included in
 build-essential is if a particular version of that package is required,
 in which case the dependency should include the version.
Renamed-From:
 depends-on-build-essential-package-without-using-version

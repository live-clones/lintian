Tag: build-depends-on-essential-package-without-using-version
Severity: error
Check: fields/package-relations
See-Also: policy 4.2
Explanation: The package declares a build-depends on an essential package, e.g. dpkg,
 without using a versioned depends. Packages do not need to build-depend on
 essential packages; essential means that they will always be present.
 The only reason to list an explicit dependency on an essential package
 is if you need a particular version of that package, in which case the
 version should be given in the dependency.

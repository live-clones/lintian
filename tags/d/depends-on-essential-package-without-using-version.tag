Tag: depends-on-essential-package-without-using-version
Severity: error
Check: fields/package-relations
See-Also: debian-policy 3.5
Explanation: The package declares a depends on an essential package, e.g. dpkg,
 without using a versioned depends. Packages do not need to depend on
 essential packages; essential means that they will always be present.
 The only reason to list an explicit dependency on an essential package
 is if you need a particular version of that package, in which case the
 version should be given in the dependency.

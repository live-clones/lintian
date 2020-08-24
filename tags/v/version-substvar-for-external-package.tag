Tag: version-substvar-for-external-package
Severity: error
Check: debian/version-substvars
Explanation: The first package has a relation on the second package using a
 dpkg-control substitution variable to generate the versioned part of
 the relation. However the second package is not built from this
 source package. Usually this means there is a mistake or typo in the
 package name in this dependency.

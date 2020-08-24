Tag: doc-package-depends-on-main-package
Severity: warning
Check: fields/package-relations
Explanation: The name of this package suggests that it is a documentation package.
 It is usually not desirable for documentation packages to depend on the
 packages they document, because users may want to install the docs before
 they decide whether they want to install the package. Also, documentation
 packages are often architecture-independent, so on other architectures
 the package on which it depends may not even exist.

Tag: missing-build-dependency
Severity: error
Check: debian/rules
See-Also: policy 4.2
Explanation: The package doesn't specify a build dependency on a package that is
 used in <code>debian/rules</code>.
 .
 Lintian intentionally does not take into account transitive dependencies.
 Even if the package build-depends on some package that in turn
 depends on the needed package, an explicit build dependency should
 be added. Otherwise, a latent bug is created that will appear without
 warning if the other package is ever updated to change its dependencies.
 Even if this seems unlikely, please always add explicit build
 dependencies on every non-essential, non-build-essential package that is
 used directly during the build.

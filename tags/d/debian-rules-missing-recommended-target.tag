Tag: debian-rules-missing-recommended-target
Severity: warning
Check: debian/rules
See-Also: policy 4.9
Explanation: The <code>debian/rules</code> file for this package does not provide
 one of the recommended targets. All of build-arch and build-indep
 should be provided, even if they don't do anything for this package.
 If this package does not currently split building of architecture
 dependent and independent packages, the following rules may be added
 to fall back to the build target:
 .
   build-arch: build
   build-indep: build
 .
 Note that the following form is recommended however:
 .
   build: build-arch build-indep
   build-arch: build-stamp
   build-indep: build-stamp
   build-stamp:
   	build here
 .
 These targets will be required by policy in the future, so should be
 added to prevent future breakage.

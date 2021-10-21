Tag: distant-prerequisite-in-shlibs
Severity: warning
Check: debian/shlibs
Renamed-From:
 shlibs-declares-dependency-on-other-package
Explanation: This package declares in its shlibs control file either a dependency
 on some other package not listed in the Provides of this package or on a
 version of this package that the package version doesn't satisfy.
 .
 Packages should normally only list in their shlibs control file the
 shared libraries included in that package, and therefore the dependencies
 listed there should normally be satisfied by either the package itself or
 one of its Provides.
 .
 In unusual circumstances where it's necessary to declare more complex
 dependencies in the shlibs control file, please add a Lintian override
 for this warning.
See-Also: policy 8.6

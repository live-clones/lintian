Tag: symbols-declares-dependency-on-other-package
Severity: warning
Check: debian/shlibs
Explanation: This package declares in its symbols control file a dependency on
 some other package (and not one listed in the Provides of this package).
 .
 Packages should normally only list in their symbols control file the
 shared libraries included in that package, and therefore the dependencies
 listed there should normally be satisfied by either the package itself or
 one of its Provides.
 .
 In unusual circumstances where it's necessary to declare more complex
 dependencies in the symbols control file, please add a Lintian override
 for this warning.
See-Also: policy 8.6

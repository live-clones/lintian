Tag: weak-library-dev-dependency
Severity: error
Check: debian/control
See-Also: policy 8.5
Explanation: The given package appears to be a shared library -dev package, but
 the dependency on what seems to be a corresponding shared library package
 does not force the same package version. To ensure that compiling and
 linking works properly, and that the symlinks in the -dev package point
 to the correct files in the shared library package, a -dev package should
 normally use <code>(= ${binary:Version})</code> for the dependency on the
 shared library package.
 .
 Sometimes, such as for -dev packages that are architecture-independent to
 not break binNMUs or when one doesn't want to force a tight dependency, a
 weaker dependency is warranted. Something like <code>(&gt;=
 ${source:Upstream-Version}), (&lt;&lt;
 ${source:Upstream-Version}+1~)</code>, possibly using
 <code>${source:Version}</code> instead, is the right approach. The goal is to
 ensure that a new upstream version of the library package doesn't satisfy
 the -dev package dependency, since the minor version of the shared
 library may have changed, breaking the <code>&ast;.so</code> links.

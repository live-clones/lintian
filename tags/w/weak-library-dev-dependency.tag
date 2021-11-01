Tag: weak-library-dev-dependency
Severity: error
Check: debian/control/prerequisite/development
Explanation: This package seems to contain the development files fer a
 shared library, but the requirement for that shared library to be installed
 does not include the same version.
 .
 A <code>-dev</code> package should normally use <code>(= ${binary:Version})</code>
 for the prerequisite on the shared library. That will ensure that programs compile
 and link properly. The symbolic links for the dynamic linker will also point to the
 correct places.
 .
 To be sure, there are some circumstances when a weak prerequisite is warranted, for
 example to prevent the breaking of binNMUs with architecture-independent <code>-dev</code>
 packages. Then something like <code>(&gt;= ${source:Upstream-Version}), (&lt;&lt;
 ${source:Upstream-Version}+1~)</code> may be the right approach, or possibly
 <code>${source:Version}</code> instead. The goal there is to ensure that a new upstream
 version of the library does not satisfy the prerequisite, since any minor version change
 might break the <code>&ast;.so</code> links.
See-Also:
 policy 8.5

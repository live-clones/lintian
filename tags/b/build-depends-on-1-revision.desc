Tag: build-depends-on-1-revision
Severity: warning
Check: fields/package-relations
Explanation: The package declares a build dependency on a version of a package
 with a -1 Debian revision such as "libfoo (&gt;= 1.2-1)". Such a
 dependency will not be satisfied by a backport of libfoo 1.2-1 and
 therefore makes backporting unnecessarily difficult. Normally, the -1
 version is unneeded and a dependency such as "libfoo (&gt;= 1.2)" would
 be sufficient. If there was an earlier -0.X version of libfoo that would
 not satisfy the dependency, use "libfoo (&gt;= 1.2-1~)" instead.

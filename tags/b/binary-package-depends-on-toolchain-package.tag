Tag: binary-package-depends-on-toolchain-package
Severity: warning
Check: fields/package-relations
Explanation: This package specifies a binary dependency on a "toolchain" package
 such as debhelper or cdbs. This is likely to be a mistake; these
 packages are typically specified as build-dependencies instead.
 .
 If the package intentionally requires such a dependency, please add a
 Lintian override with a justifying remark.

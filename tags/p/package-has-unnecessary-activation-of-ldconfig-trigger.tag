Tag: package-has-unnecessary-activation-of-ldconfig-trigger
Severity: warning
Check: libraries/shared/trigger/ldconfig
Explanation: The package activates the ldconfig trigger even though no shared
 libraries are installed in a directory controlled by the dynamic
 library loader.
 .
 Note this may be triggered by a bug in debhelper, that causes it to
 auto-generate an ldconfig trigger for packages that do not need it.
See-Also:
 policy 8.1.1,
 Bug#204975

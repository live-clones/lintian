Tag: intra-source-package-circular-dependency
Severity: warning
Check: group-checks
Explanation: The listed packages from the same source circularly depend
 (or pre-depend) on each other. This makes it difficult for tools
 to properly handle install/upgrade sequences. Furthermore this
 complicates automated removal of unused packages.
 .
 If possible, consider removing or reducing one of the depends.
 .
 Note: This check is limited to packages created from the same
 source package. Full circular dependencies between binaries from
 different source packages is beyond the scope of Lintian.
See-Also: policy 7.2

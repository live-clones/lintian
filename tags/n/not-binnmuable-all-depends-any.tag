Tag: not-binnmuable-all-depends-any
Severity: error
Check: debian/version-substvars
Explanation: The package is not safely binNMUable because an arch:all package
 depends on an arch:any package with a strict (= ${source:Version}), or
 similar, relationship.
 .
 It is not possible for arch:all packages to depend so strictly on
 arch:any packages while having the package binNMUable, so please use
 one of these, whichever is more appropriate:
 .
   Depends: arch&lowbar;any (&gt;= ${source:Version})
   Depends: arch&lowbar;any (&gt;= ${source:Version}),
    arch&lowbar;any (&lt;&lt; ${source:Version}.1~)

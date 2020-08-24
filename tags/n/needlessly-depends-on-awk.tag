Tag: needlessly-depends-on-awk
Severity: error
Check: fields/package-relations
Explanation: The package seems to declare a relation on awk. awk is a virtual
 package, but it is special since it's de facto essential. If you don't
 need to depend on a specific version of awk (which wouldn't work anyway,
 as dpkg doesn't support versioned provides), you should remove the
 dependency on awk.

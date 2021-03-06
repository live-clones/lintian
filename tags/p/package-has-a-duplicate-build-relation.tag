Tag: package-has-a-duplicate-build-relation
Severity: warning
Check: fields/package-relations
Explanation: The package declares the given build relations on the same package
 in either Build-Depends or Build-Depends-Indep, but the build relations
 imply each other and are therefore redundant.

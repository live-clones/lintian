Tag: redundant-build-prerequisites
Severity: warning
Check: fields/package-relations
Renamed-From:
 package-has-a-duplicate-build-relation
Explanation: The source declares a variety of build prerequisites
 in <code>Build-Depends</code>, <code>Build-Depends-Indep</code>,
 or <code>Build-Depends-Arch</code> but the fields work together.
 The given set contains redundant information.
 .
 Please simplify the build prerequisites.

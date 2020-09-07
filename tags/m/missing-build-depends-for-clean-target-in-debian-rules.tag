Tag: missing-build-depends-for-clean-target-in-debian-rules
Severity: error
Check: debian/rules
Renamed-From: clean-should-be-satisfied-by-build-depends
See-Also: policy 7.7
Explanation: The specified package is required to run the clean target of
 <code>debian/rules</code> and therefore must be listed in Build-Depends, not
 Build-Depends-Indep, even if no architecture-dependent packages are
 built.

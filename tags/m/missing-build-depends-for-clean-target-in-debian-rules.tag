Tag: missing-build-depends-for-clean-target-in-debian-rules
Severity: error
Check: debian/rules
Renamed-From:
 clean-should-be-satisfied-by-build-depends
Explanation: The specified condition must be satisfied to run the <code>clean</code>
 target in <code>debian/rules</code>.
 .
 Please add a suitable prerequisite to <code>Build-Depends</code> (and not
 <code>Build-Depends-Indep</code>) even if no architecture-dependent packages
 are being built.
 .
 The condition you see in the context is not a recommendation on what to add. If
 you see a list, more than likely only one member is needed to make this tag go
 away. You probably also do not need the <code>:any</code> multiarch acceptor,
 if you see one.
See-Also:
 policy 7.7

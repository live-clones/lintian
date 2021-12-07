Tag: debian-rules-missing-recommended-target
Severity: warning
Check: debian/rules
Explanation: The <code>debian/rules</code> file for this package does not
 provide all recommended targets. Both <code>build-arch</code> and
 <code>build-indep</code> should be provided, even if they do not do
 anything.
 .
 If this package does not currently split the building of architecture
 dependent and independent packages, the following rules may be added
 to fall back to the <code>build</code> target:
 .
     build-arch: build
     build-indep: build
 .
 Note, however, that the following form is recommended:
 .
     build: build-arch build-indep
     build-arch: build-stamp
     build-indep: build-stamp
     build-stamp:
         build here
 .
 Future versions of the policy will require these targets. Please add
 them to avoid future breakage.
See-Also:
 debian-policy 4.9

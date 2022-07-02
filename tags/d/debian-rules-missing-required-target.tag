Tag: debian-rules-missing-required-target
Severity: error
Check: debian/rules
Explanation: The <code>debian/rules</code> file does not provide all required
 targets. Both <code>build-arch</code> and <code>build-indep</code> must be
 provided even if they do nothing.
 .
 For sources that do not currently split the building of architecture dependent
 and independent installables, the following rules will fall back on the
 <code>build</code> target:
 .
     build-arch: build
     build-indep: build
 .
 Some say that the following form is recommended:
 .
     build: build-arch build-indep
     build-arch: build-stamp
     build-indep: build-stamp
     build-stamp:
         build here
 .
 As a modern alternative, you may wish to use the <code>dh</code> sequencer
 instead. Your sources will no longer be affected by this issue.
 .
 Policy now requires those targets. Please add them to avoid rejection.
 .
 In your next upload, please also close the bug from the mass bug filing you
 received. Details are described in the message to <code>debian-devel</code>
 cited below.
See-Also:
 debian-policy 4.9,
 https://lists.debian.org/debian-devel/2021/11/msg00052.html

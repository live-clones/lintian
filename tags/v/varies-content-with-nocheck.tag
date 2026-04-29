Tag: varies-content-with-nocheck
Severity: error
Check: debian/control/field/build-profiles
Explanation: The nocheck build profile is used to disable binary
 packages from being built while the profile is expected to not vary
 the resulting artifacts at all.
 .
 There is a use case for skipping the installation of benchmarks, samples
 and test programs and it is served by the noinsttest build profile.
 .
 If a build dependency is needed both to run build-time tests and to build
 installed tests that reside in a separate binary package with !noinsttest
 build profile, it should be annotated with <!nocheck> <!noinsttest>.
 It can then only be skipped when both profiles are supplied at the same time.

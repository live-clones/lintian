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
 If a build dependency is required for running build-time tests or
 installed tests, it should be annotated <!nocheck> <!noinsttest>.
 Then it can only be skipped when supplying both profiles at the same time.

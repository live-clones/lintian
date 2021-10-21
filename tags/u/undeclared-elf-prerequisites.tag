Tag: undeclared-elf-prerequisites
Severity: warning
Check: binaries/prerequisites
Renamed-From:
 missing-depends-line
Explanation: The installation package contains an ELF executable or object file
 with dynamic references but does not declare any package prerequisites. The
 Depends field in the installation <code>control</code> file is empty.
 .
 This usually happens when <code>Depends</code> field in the source control file
 does not mention <code>${shlibs:Depends}</code> or, when not using the
 <code>dh</code> sequencer, there is no call to <code>dpkg-shlibdeps</code> in
 <code>debian/rules</code>.

Tag: epoch-changed-but-upstream-version-did-not-go-backwards
Severity: error
Check: debian/changelog
Explanation: The previous version of this package had a different version epoch
 to the current version but the upstream version did not go "backwards".
 For example, the previous package version was "1:1.0-1" and the current
 version is "2:2.0-1".
 .
 This was likely an accidental bump or addition of an epoch.
 .
 Epochs exist to cope with changes to the upstream version numbering
 scheme. Whilst they are a powerful tool, increasing or adding an epoch
 has many downsides including causing issues with versioned dependencies,
 being misleading to users and being aesthetically unappealing. Whilst
 they should be avoided, valid reasons to add or increment the epoch
 include:
 .
  - Upstream changed their versioning scheme in a way that makes the
    latest version lower than the previous one.
  - You need to permanently revert to a lower upstream version.
 .
 Temporary revertions (eg. after an NMU) should use not modify or
 introduce an epoch - please use the <code>CURRENT+reallyFORMER</code> until
 you can upload the latest version again.
 .
 If you are unsure whether you need to increase the epoch for a package,
 please consult the debian-devel mailing list.

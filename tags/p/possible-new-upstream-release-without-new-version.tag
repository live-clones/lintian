Tag: possible-new-upstream-release-without-new-version
Severity: warning
Check: debian/changelog
Explanation: The most recent changelog entry contains an entry that appears to
 say this is a new upstream release (a comment similar to "new upstream
 release," possibly with a word between "upstream" and "release"), but the
 upstream portion of the package version number didn't change. This may
 indicate that the package version was not updated properly in
 <code>debian/changelog</code>.

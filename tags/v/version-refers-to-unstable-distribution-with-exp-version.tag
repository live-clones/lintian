Tag: version-refers-to-unstable-distribution-with-exp-version
Severity: warning
Check: debian/changelog
Explanation: The Debian portion of the package version contains a reference to the
 experimental distribution via the <code>~exp</code> or <code>~experimental</code>
 pattern but the release is targeting unstable.
 .
 Please make sure the targeted release and the version number match.

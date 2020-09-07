Tag: changelog-distribution-does-not-match-changes-file
Severity: warning
Check: debian/changelog
Explanation: The target distribution in the most recent entry in this package's
 <code>debian/changelog</code> file does not match the target in the generated
 <code>.changes</code> file.
 .
 This may indicate a mistake in setting the distribution, an accidental
 upload to unstable of a package intended for experimental, or a mistake
 in invoking <code>sbuild(1)</code>.
See-Also: Bug#906155, sbuild(1)

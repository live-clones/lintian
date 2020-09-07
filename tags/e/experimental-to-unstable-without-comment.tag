Tag: experimental-to-unstable-without-comment
Severity: pedantic
Check: debian/changelog
Explanation: The previous version of this package had a distribution of
 "experimental", this version has a distribution of "unstable", and there's
 apparently no comment about the change of distributions.
 .
 Lintian looks in this version's changelog entry for the phrase "to
 unstable" or "to sid", with or without quotation marks around the
 distribution name.
 .
 This may indicate a mistake in setting the distribution and an accidental
 upload to unstable of a package intended for experimental.

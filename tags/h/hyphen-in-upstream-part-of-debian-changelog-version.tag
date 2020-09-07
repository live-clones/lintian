Tag: hyphen-in-upstream-part-of-debian-changelog-version
Severity: pedantic
Check: debian/changelog
Explanation: The upstream version in the debian changelog contains one or more
 hyphens. While that is okay according to Debian Policy, some tools may
 croak.
See-Also: policy 5.6.12

Tag: no-changelog
Severity: error
Check: debian/changelog
Renamed-From:
 changelog-file-missing-in-native-package
 debian-changelog-file-missing
Explanation: A Debian package that provides a <code>/usr/share/doc/*pkg*</code>
 directory must install a changelog file.
 .
 For native packages the best name is
 <code>/usr/share/doc/*pkg*/changelog.gz</code>.
 .
 For non-native packages the best name is
 <code>/usr/share/doc/*pkg*/changelog.Debian.gz</code>.
 .
 This tag may also be emitted when the changelog exists but does not
 otherwise resemble a Debian changelog.
See-Also: policy 12.7

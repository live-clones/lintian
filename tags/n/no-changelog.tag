Tag: no-changelog
Severity: error
Check: debian/changelog
Renamed-From:
 changelog-file-missing-in-native-package
 debian-changelog-file-missing
Explanation: A Debian package that provides a <tt>/usr/share/doc/<i>pkg</i></tt>
 directory must install a changelog file.
 .
 For native packages the best name is
 <tt>/usr/share/doc/<i>pkg</i>/changelog.gz</tt>.
 .
 For non-native packages the best name is
 <tt>/usr/share/doc/<i>pkg</i>/changelog.Debian.gz</tt>.
 .
 This tag may also be emitted when the changelog exists but does not
 otherwise resemble a Debian changelog.
See-Also: policy 12.7

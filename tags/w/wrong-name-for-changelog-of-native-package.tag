Tag: wrong-name-for-changelog-of-native-package
Severity: warning
Check: debian/changelog
Explanation: The changelog file of a native Debian package (ie. if there is
 no upstream source) should usually be installed as
 /usr/share/doc/*pkg*/changelog.gz
See-Also: policy 12.7

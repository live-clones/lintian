Tag: debian-changelog-file-missing-or-wrong-name
Severity: error
Check: debian/changelog
Explanation: Each Debian package (which provides a /usr/share/doc/<i>pkg</i>
 directory) must install a Debian changelog file in
 /usr/share/doc/<i>pkg</i>/changelog.Debian.gz
 .
 A common error is to name the Debian changelog like an upstream changelog
 (/usr/share/doc/<i>pkg</i>/changelog.gz); therefore, Lintian will apply
 further checks to such a file if it exists even after issuing this error.
See-Also: policy 12.7

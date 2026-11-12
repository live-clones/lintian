Tag: orig-tarball-contains-ancient-file
Severity: info
Check: files/date
Explanation: The orig tarball contains a file that claims to have been
 generated before 1976. This old date may carry over to the binary packages
 when building from the sources unpacked with "dpkg-source -x package.dsc",
 for example. In this case the generated package will be rejected by the
 Debian archive scripts.

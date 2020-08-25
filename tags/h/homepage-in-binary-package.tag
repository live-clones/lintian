Tag: homepage-in-binary-package
Severity: info
Check: fields/homepage
Explanation: This non-native source package produces at least one binary package
 with a <code>Homepage</code> field. However, the source package itself has
 no <code>Homepage</code> field. Unfortunately, this results in some
 source-based tools/services (e.g. the PTS) not linking to the homepage
 of the upstream project.
 .
 If you move the <code>Homepage</code> field to the source paragraph in
 <code>debian/control</code> then all binary packages from this source
 will inherit the value by default.
See-Also: policy 5.6.23

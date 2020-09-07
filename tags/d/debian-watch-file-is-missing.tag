Tag: debian-watch-file-is-missing
Severity: info
Check: debian/watch
See-Also: policy 4.11, uscan(1)
Explanation: This source package is not Debian-native but it does not have a
 <code>debian/watch</code> file. This file is used for automatic detection of
 new upstream versions by the Debian External Health Status project and
 other project infrastructure. If this package is maintained upstream,
 please consider adding a <code>debian/watch</code> file to detect new
 releases.
 .
 If the package is not maintained upstream or if upstream uses a
 distribution mechanism that cannot be meaningfully monitored by uscan
 and the Debian External Health Status project, please consider adding a
 <code>debian/watch</code> file containing only comments documenting the
 situation.

Tag: upstream-metadata-in-native-source
Severity: warning
Check: debian/upstream/metadata
See-Also: https://dep-team.pages.debian.net/deps/dep12/, https://wiki.debian.org/UpstreamMetadata
Explanation: This source package is Debian-native and has a
 <code>debian/upstream/metadata</code> file.
 . 
 The Upstream MEtadata GAthered with YAml (UMEGAYA) project is an effort
 to collect meta-information about upstream projects from any source
 package. This file is in YAML format and it is used in to feed the data
 in the UltimateDebianDatabase. For example, it can contains the way the
 authors want their software be cited in publications and some
 bibliographic references about the software.
 .
 Please remove the <code>debian/upstream/metadata</code> file.

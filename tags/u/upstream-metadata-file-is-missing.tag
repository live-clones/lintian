Tag: upstream-metadata-file-is-missing
Severity: pedantic
Check: debian/upstream/metadata
Experimental: yes
See-Also: https://dep-team.pages.debian.net/deps/dep12/, https://wiki.debian.org/UpstreamMetadata
Explanation: This source package is not Debian-native but it does not have a
 <code>debian/upstream/metadata</code> file.
 . 
 The Upstream MEtadata GAthered with YAml (UMEGAYA) project is an effort
 to collect meta-information about upstream projects from any source
 package. This file is in YAML format and it is used in to feed the data
 in the UltimateDebianDatabase. For example, it can contains the way the
 authors want their software be cited in publications and some
 bibliographic references about the software.
 .
 Please add a <code>debian/upstream/metadata</code> file.

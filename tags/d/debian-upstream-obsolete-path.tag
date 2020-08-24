Tag: debian-upstream-obsolete-path
Severity: error
Check: cruft
Explanation: Upstream metadata is stored under an obsolete path.
 .
 Upstream MEtadata GAthered with YAml (UMEGAYA) is an effort to collect
 meta-information about upstream projects from any source package
 with a publicly accessible VCS via a file called
 <tt>debian/upstream/metadata</tt>.
 .
 Older versions of this specification used
 <tt>debian/upstream-metadata.yaml</tt> or <tt>debian/upstream</tt>
 as meta-information storage file.
 .
 You should move any such file to <tt>debian/upstream/metadata</tt>.

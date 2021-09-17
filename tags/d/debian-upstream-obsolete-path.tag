Tag: debian-upstream-obsolete-path
Severity: error
Check: debian/upstream/metadata
Explanation: Upstream metadata is stored under an obsolete path.
 .
 Upstream MEtadata GAthered with YAml (UMEGAYA) is an effort to collect
 meta-information about upstream projects from any source package
 with a publicly accessible VCS via a file called
 <code>debian/upstream/metadata</code>.
 .
 Older versions of this specification used
 <code>debian/upstream-metadata.yaml</code> or <code>debian/upstream</code>
 as meta-information storage file.
 .
 You should move any such file to <code>debian/upstream/metadata</code>.

Tag: debian-watch-lacks-sourceforge-redirector
Severity: warning
Check: debian/watch
Renamed-From: debian-watch-file-should-use-sf-redirector
See-Also: uscan(1)
Explanation: The watch file specifies a SourceForge page or download server
 directly. This is not recommended; SourceForge changes their download
 servers and website periodically, requiring watch files to be modified
 every time. Instead, use the qa.debian.org redirector by using the magic
 URL:
 .
   http://sf.net/&lt;project&gt;/&lt;tar-name&gt;-(.+)\.tar\.gz
 .
 replacing <code>&lt;project&gt;</code> with the name of the SourceForge
 project and <code>&lt;tar-name&gt;</code> with the name of the tarball
 distributed within that project. Adjust the filename regex as necessary.

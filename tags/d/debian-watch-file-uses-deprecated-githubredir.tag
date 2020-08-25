Tag: debian-watch-file-uses-deprecated-githubredir
Severity: error
Check: debian/watch
See-Also: https://lists.debian.org/debian-devel-announce/2014/10/msg00000.html
Explanation: The watch file specifies a githubredir.debian.net URL, which is deprecated
 Instead, use direct links to the tags page:
 .
  version=3
  https://github.com/&lt;user&gt;/&lt;project&gt;/tags .&ast;/(.&ast;)\.tar\.gz
 .
 replacing <code>&lt;user&gt;</code> and <code>&lt;project&gt;</code> with the Github
 username and project respectively.

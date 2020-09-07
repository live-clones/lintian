Tag: depends-on-old-emacs
Severity: warning
Check: fields/package-relations
Explanation: The package lists an old version of Emacs as its first dependency.
 It should probably be updated to support the current version of Emacs
 in the archive and then list that version first in the list of Emacs
 flavors it supports.
 .
 If the package intentionally only supports older versions of Emacs (if,
 for example, it was included with later versions of Emacs), add a Lintian
 override.

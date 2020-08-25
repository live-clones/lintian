Tag: debian-watch-file-uses-deprecated-sf-redirector-method
Severity: warning
Check: debian/watch
Explanation: The watch file seems to be passing arguments to the redirector
 other than a path. Calling the SourceForge redirector with parameters like
 <code>project</code> prevents uscan from generating working URIs to the files
 and thus has been deprecated and is no longer supported by the redirector.

Tag: odd-static-library-name
Severity: warning
Check: libraries/static/name
Explanation: The package installs a static library under a strange name.
 .
 Some naming schemes make it harder to switch from static
 to dynamic building. On such example is to install archives with
 a name suffix such as <code>libyajl&lowbar;s.a</code>.
 .
 Please reconsider the choice of the file name.
See-Also:
 Bug#698398

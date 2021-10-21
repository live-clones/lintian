Tag: symbols-file-contains-current-version-with-debian-revision
Severity: error
Check: debian/shlibs
Explanation: Debian revisions should be stripped from versions in symbols files.
 Not doing so leads to dependencies unsatisfiable by backports (1.0-1~bpo
 &lt;&lt; 1.0-1 while 1.0-1~bpo &gt;= 1.0). If the Debian revision can't
 be stripped because the symbol really appeared between two specific
 Debian revisions, you should postfix the version with a single "~"
 (example: 1.0-3~ if the symbol appeared in 1.0-3).
 .
 This problem normally means that the symbols were added automatically by
 dpkg-gensymbols. dpkg-gensymbols uses the full version number for the
 dependency associated to any new symbol that it detects. The maintainer
 must update the <code>debian/&lt;package&gt;.symbols</code> file by adding
 the new symbols with the corresponding upstream version.

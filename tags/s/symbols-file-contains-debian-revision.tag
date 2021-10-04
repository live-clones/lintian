Tag: symbols-file-contains-debian-revision
Severity: warning
Check: debian/shlibs
Explanation: Debian revisions should be stripped from versions in symbols files.
 Not doing so leads to dependencies unsatisfiable by backports (1.0-1~bpo
 &lt;&lt; 1.0-1 while 1.0-1~bpo &gt;= 1.0). If the Debian revision can't
 be stripped because the symbol really appeared between two specific
 Debian revisions, you should postfix the version with a single "~"
 (example: 1.0-3~ if the symbol appeared in 1.0-3).
See-Also: dpkg-gensymbols(1), https://wiki.debian.org/UsingSymbolsFiles

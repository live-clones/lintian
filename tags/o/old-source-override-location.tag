Tag: old-source-override-location
Severity: pedantic
Check: debian/lintian-overrides
Renamed-From: package-uses-deprecated-source-override-location
Explanation: This Debian package ships Lintian source-level overrides in the
 <code>debian/source.lintian-overrides</code> file.
 .
 Please use <code>debian/source/lintian-overrides</code> instead; the
 <code>debian/source</code> directory is preferred to hold "source"-specific
 files.
See-Also: lintian 2.4

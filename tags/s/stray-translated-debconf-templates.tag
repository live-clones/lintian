Tag: stray-translated-debconf-templates
Severity: warning
Check: debian/po-debconf
Explanation: This package contains a file named &ast;templates.XX or
 &ast;templates.XX&lowbar;XX. This was the naming convention for the translated
 templates merged using debconf-mergetemplate. Since the package is using
 po-debconf, these files should be replaced by language-specific files in
 the <code>debian/po</code> directory and should no longer be needed.

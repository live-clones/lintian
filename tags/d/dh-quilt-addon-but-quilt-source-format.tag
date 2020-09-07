Tag: dh-quilt-addon-but-quilt-source-format
Severity: warning
Check: debhelper
Explanation: The package uses (for example) <code>dh $@ --with quilt</code> in
 <code>debian/rules</code> but is already using the <code>3.0 (quilt)</code>
 source format via the <code>debian/source/format</code> file.
 .
 Please remove the <code>--with quilt</code> argument.

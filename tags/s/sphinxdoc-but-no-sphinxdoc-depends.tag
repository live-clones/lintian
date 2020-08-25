Tag: sphinxdoc-but-no-sphinxdoc-depends
Severity: warning
Check: debhelper
See-Also: dh_sphinxdoc(1)
Explanation: The source package uses Sphinx via <code>--with sphinxdoc</code> or
 <code>dh&lowbar;sphinxdoc</code> but no binary package specifies
 <code>${sphinxdoc:Depends}</code> as a dependency.
 .
 The <code>sphinxdoc</code> helper is being used to make links to various
 common files from other binary packages that are injected via the
 <code>${sphinxdoc:Depends}</code> substitution variable.
 .
 Please add <code>${sphinxdoc:Depends}</code> to the relevant binary
 package.

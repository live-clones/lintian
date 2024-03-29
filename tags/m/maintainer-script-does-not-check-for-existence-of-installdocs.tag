Tag: maintainer-script-does-not-check-for-existence-of-installdocs
Severity: error
Check: menus
Explanation: The maintainer script calls the <code>install-docs</code> command without
 checking that it exists, but the <code>doc-base</code> package, which provides
 the command, is not an <code>essential</code> package and may not be available.
 .
 For example, you can use the following code in your maintainer script:
 .
     if which install-docs &gt; /dev/null; then
          install-docs -i /usr/share/doc-base/&lt;your-package&gt;
     fi

Tag: maintainer-script-does-not-check-for-existence-of-installdocs
Severity: error
Check: menus
Explanation: The maintainer script calls the <code>install-docs</code> command without
 checking for existence first. (The <code>doc-base</code> package which provides
 the command is not marked as "essential" package.)
 .
 For example, use the following code in your maintainer script:
  if which install-docs &gt; /dev/null; then
    install-docs -i /usr/share/doc-base/&lt;your-package&gt;
  fi

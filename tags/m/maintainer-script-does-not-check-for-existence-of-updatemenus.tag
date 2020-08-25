Tag: maintainer-script-does-not-check-for-existence-of-updatemenus
Severity: error
Check: menus
Explanation: The maintainer script calls the <code>update-menus</code> command without
 checking for existence first. (The <code>menu</code> package which provides the
 command is not marked as "essential" package.)
 .
 For example, use the following code in your maintainer script:
 .
  if which update-menus &gt; /dev/null; then update-menus ; fi

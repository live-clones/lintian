Tag: maintainer-script-does-not-check-for-existence-of-updatemenus
Severity: error
Check: menus
Explanation: The given maintainer script calls the <code>update-menus</code>
 command but does not check if it exists.
 .
 The <code>menu</code> package that provides the command is not an "essential"
 package.
 .
 For example, you can use the following code in your maintainer script:
 .
     if which update-menus &gt; /dev/null; then
         update-menus
     fi

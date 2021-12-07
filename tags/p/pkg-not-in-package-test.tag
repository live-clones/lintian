Tag: pkg-not-in-package-test
Severity: warning
Check: menu-format
Explanation: The given <code>menu</code> item does not check if the package that
 ships the application is installed.
 .
 Each <code>menu</code> item should begin with a check that the required packages
 are installed. At a minimum, the condition should check that the package that
 ships the application is installed.
 .
 Menu items are normally shiiped in the same package that also provides the
 application the <code>menu</code> item is for.
 .
 Sometimes this issue arises the package name was mespelled in the <code>menu</code>
 entry, or an entry was copied from another package but not properly adjusted.
See-Also:
 menu-manual 3.2

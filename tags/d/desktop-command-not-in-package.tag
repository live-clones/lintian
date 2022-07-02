Tag: desktop-command-not-in-package
Severity: warning
Check: menu-format
Explanation: The desktop entry specifies a <code>Command</code> that does not
 match any of the executables shipped in the package.
 .
 This condition is often caused by a typo, or the desktop file was not updated
 after the installed path of the executable was modified.
 .
 Packages should ship executables that are used as commands in <code>desktop</code>
 files.

Tag: prerm-calls-updatemenus
Severity: error
Check: menus
Explanation: The <code>prerm</code> maintainer script calls the
 <code>update-menus</code> command.
 .
 Usually, this command should be called from the <code>postrm</code>
 maintainer script.

Tag: postrm-calls-installdocs
Severity: error
Check: menus
Explanation: The postrm script calls the <code>install-docs</code> command. Usually,
 this command should be called from the <code>prerm</code> maintainer script.

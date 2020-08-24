Tag: postrm-calls-installdocs
Severity: error
Check: menus
Explanation: The postrm script calls the <tt>install-docs</tt> command. Usually,
 this command should be called from the <tt>prerm</tt> maintainer script.

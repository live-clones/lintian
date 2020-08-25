Tag: bad-whatis-entry
Severity: warning
Check: documentation/manual
Renamed-From: manpage-has-bad-whatis-entry
Explanation: A manual page should start with a <code>NAME</code> section, which
 lists the program name and a brief description. The <code>NAME</code>
 section is used to generate a database that can be queried by commands
 like <code>apropos</code> and <code>whatis</code>. You are seeing this tag
 because <code>lexgrog</code> was unable to parse the <code>NAME</code> section.
 .
 Manual pages for multiple programs, functions, or files should list each
 separated by a comma and a space, followed by <code>\-</code> and a common
 description.
 .
 Listed items may not contain any spaces. A manual page for a two-level
 command such as <code>fs listacl</code> must look like <code>fs&lowbar;listacl</code>
 so the list is read correctly.
See-Also: lexgrog(1), groff_man(7), groff_mdoc(7)

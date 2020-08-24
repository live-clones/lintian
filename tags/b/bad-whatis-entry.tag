Tag: bad-whatis-entry
Severity: warning
Check: documentation/manual
Renamed-From: manpage-has-bad-whatis-entry
Explanation: A manual page should start with a <tt>NAME</tt> section, which
 lists the program name and a brief description. The <tt>NAME<tt>
 section is used to generate a database that can be queried by commands
 like <tt>apropos</tt> and <tt>whatis</tt>. You are seeing this tag
 because <tt>lexgrog</tt> was unable to parse the <tt>NAME</tt> section.
 .
 Manual pages for multiple programs, functions, or files should list each
 separated by a comma and a space, followed by <tt>\-</tt> and a common
 description.
 .
 Listed items may not contain any spaces. A manual page for a two-level
 command such as <tt>fs listacl</tt> must look like <tt>fs_listacl</tt>
 so the list is read correctly.
See-Also: lexgrog(1), groff_man(7), groff_mdoc(7)

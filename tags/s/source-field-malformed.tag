Tag: source-field-malformed
Severity: error
Check: fields/source
Explanation: In <tt>debian/control</tt> or a <tt>.dsc</tt> file, the Source field
 must contain only the name of the source package. In a binary package,
 the Source field may also optionally contain the version number of the
 corresponding source package in parentheses.
 .
 Source package names must consist only of lowercase letters, digits,
 plus and minus signs, and periods. They must be at least two characters
 long and must start with an alphanumeric character.
See-Also: policy 5.6.1

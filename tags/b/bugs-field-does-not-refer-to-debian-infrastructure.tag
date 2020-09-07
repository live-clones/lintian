Tag: bugs-field-does-not-refer-to-debian-infrastructure
Severity: warning
Check: fields/bugs
Explanation: The <code>debian/control</code> file contains a Bugs field that does
 not refer to Debian infrastructure. This is recognized by the string
 ".debian.org".
 .
 This is likely to make reportbug(1) unable to report bugs.
See-Also: Bug#740944

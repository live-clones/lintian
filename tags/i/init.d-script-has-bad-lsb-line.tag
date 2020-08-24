Tag: init.d-script-has-bad-lsb-line
Severity: warning
Check: init.d
See-Also: https://wiki.debian.org/LSBInitScripts
Explanation: This line in the LSB keyword section of an <tt>/etc/init.d</tt>
 script doesn't match the required formatting of that section. Note that
 keyword settings must start with <tt>#</tt>, a single space, the keyword,
 a colon, and some whitespace, followed by the value (if any). Only the
 Description keyword allows continuation lines, and continuation lines
 must begin with <tt>#</tt> and either a tab or two or more spaces.

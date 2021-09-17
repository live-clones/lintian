Tag: init.d-script-has-bad-lsb-line
Severity: warning
Check: init-d
See-Also: https://wiki.debian.org/LSBInitScripts
Explanation: This line in the LSB keyword section of an <code>/etc/init.d</code>
 script doesn't match the required formatting of that section. Note that
 keyword settings must start with <code>#</code>, a single space, the keyword,
 a colon, and some whitespace, followed by the value (if any). Only the
 Description keyword allows continuation lines, and continuation lines
 must begin with <code>#</code> and either a tab or two or more spaces.

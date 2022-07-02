Tag: read-in-maintainer-script
Severity: error
Check: scripts
Explanation: The given maintainer script appears to use <code>read</code> to
 get information from the user. Prompting in maintainer scripts must be done
 by communicating through a utility that conforms to the Debian configuration
 management specification, version 2 or higher. The <code>debconf</code>
 program is a popular choice.
 .
 With this tag, there is a potential for false positives. For example,
 <code>read</code> could be used in a block with redirection, in a function
 in a pipe, or when standard input is provided in an unusual way.
See-Also:
 debian-policy 3.9.1

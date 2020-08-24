Tag: read-in-maintainer-script
Severity: error
Check: scripts
See-Also: policy 3.9.1 
Explanation: This maintainer script appears to use read to get information from
 the user. Prompting in maintainer scripts must be done by communicating
 through a program such as debconf which conforms to the Debian
 Configuration management specification, version 2 or higher.
 .
 This check can have false positives if read is used in a block with a
 redirection, in a function run in a pipe, or in other ways where
 standard input is provided in inobvious ways. If this is the case, please
 add an override for this tag.

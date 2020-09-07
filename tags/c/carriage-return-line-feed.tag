Tag: carriage-return-line-feed
Severity: error
Check: debian/line-separators
Renamed-From: control-file-with-CRLF-EOLs
Explanation: The given control file uses <code>CRLF</code> as line terminator
 instead of the traditional UNIX <code>LF</code> terminator. Since some
 tools were only designed with the UNIX end-of-line terminators in mind,
 it is possible that they misbehave or lead to unexpected results.
 .
 Running the following command against the given file removes any
 <code>CR</code> character in the file:
 .
 <code>sed -i 's/\r//g' path/to/file</code>

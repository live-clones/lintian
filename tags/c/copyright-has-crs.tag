Tag: copyright-has-crs
Severity: pedantic
Check: debian/copyright
Explanation: The copyright file has lines ending in CRLF instead of just LF.
 .
 Running the following command against the given file removes any
 <code>CR</code> character in the file:
 .
 <code>sed -i 's/\r//g' path/to/file</code>

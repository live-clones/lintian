Tag: desktop-entry-file-has-crs
Severity: warning
Check: menu-format
Explanation: The desktop entry file has lines ending in CRLF instead of just LF.
 The Desktop Entry Specification is explicit that lines should end with
 only LF. The CR may be taken by some software as part of the field.
 .
 Running the following command against the given file removes any
 <code>CR</code> character in the file:
 .
 <code>sed -i 's/\r//g' path/to/file</code>
See-Also: https://specifications.freedesktop.org/desktop-entry-spec/latest/ar01s03.html

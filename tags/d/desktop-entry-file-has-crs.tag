Tag: desktop-entry-file-has-crs
Severity: warning
Check: menu-format
Explanation: The desktop entry file has lines ending in carriage-return and line-feed
 instead of just a line-feed. The Desktop Entry Specification says that lines should
 end with line-feed alone.
 .
 Some software may mistake the carriage-return as a part of the field value.
 .
 You can run the following command to remove any <code>CR</code> character in a file:
 .
      <code>sed -i 's/\r//g' path/to/file</code>
See-Also:
 https://specifications.freedesktop.org/desktop-entry-spec/latest/ar01s03.html

Tag: changelog-is-dh_make-template
Severity: error
Check: debian/changelog
Explanation: The changelog file has an instruction left by dh&lowbar;make, which has
 not been removed. Example:
 .
   - Initial release (Closes: #nnnn)  &lt;nnnn is the bug number of your ITP&gt;
 .
 The "&lt;... is the bug number ...&gt;" part has not been removed from the
 changelog.

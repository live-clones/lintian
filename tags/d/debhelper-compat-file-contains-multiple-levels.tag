Tag: debhelper-compat-file-contains-multiple-levels
Severity: error
Check: debhelper
See-Also: debhelper(7)
Explanation: The <code>debian/compat</code> file appears to contain multiple
 compatibility levels.
 .
 This was likely due to the use of &gt;&gt; instead of &gt; when
 updating the level.
 .
 Please update the file to specify a single level.

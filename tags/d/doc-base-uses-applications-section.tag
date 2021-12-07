Tag: doc-base-uses-applications-section
Severity: warning
Check: menus
Explanation: The section indicated in the given <code>doc-base</code>
 control file uses a top-level section named <code>Apps</code> or
 <code>Applications</code>. Those names are only used in <code>menu</code>,
 but not in <code>doc-base</code>.
 .
 You may just be able to drop the <code>Applications/</code> part in the
 section.
See-Also:
 doc-base-manual 2.3.3

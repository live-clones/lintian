Tag: desktop-entry-unknown-type
Severity: warning
Check: menu-format
Explanation: This <code>desktop</code> entry uses a <code>Type</code> that is
 not among the currently recognized values of <code>Application</code>,
 <code>Link</code> or <code>Directory</code>.
 .
 Implementations normally ignore unknown values but this condition is probably
 not intended.
 .
 The values are case-sensitive.
 .
 The <code>desktop-file-validate</code> tool in the <code>desktop-file-utils</code>
 package may be useful when checking the syntax of desktop entries.
See-Also:
 https://specifications.freedesktop.org/desktop-entry-spec/latest/ar01s06.html

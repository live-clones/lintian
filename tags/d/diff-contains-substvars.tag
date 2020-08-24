Tag: diff-contains-substvars
Severity: warning
Check: cruft
Explanation: Lintian found a substvars file in the Debian diff for this source
 package. The debian/substvars (or debian/<tt>package</tt>.substvars) file
 is usually generated and modified dynamically by debian/rules targets, in
 which case it must be removed by the clean target.
See-Also: policy 4.10

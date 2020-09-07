Tag: bad-distribution-in-changes-file
Severity: error
Check: fields/distribution
Explanation: You've specified an unknown target distribution for your upload in
 the <code>debian/changelog</code> file. It is possible that you are uploading
 for a different distribution than the one Lintian is checking for. In
 that case, passing --profile $VENDOR may fix this warning.
 .
 Note that the distributions <code>non-free</code> and <code>contrib</code> are no
 longer valid. You'll have to use distribution <code>unstable</code> and
 <code>Section: non-free/xxx</code> or <code>Section: contrib/xxx</code> instead.
See-Also: policy 5.6.14

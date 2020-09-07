Tag: multiple-distributions-in-changes-file
Severity: error
Check: fields/distribution
Explanation: You've specified more than one target distribution for your upload
 in the <code>&ast;.changes</code> file, probably via the most recent entry in the
 <code>debian/changelog</code> file.
 .
 Although this syntax is valid, it is not accepted by the Debian archive
 management software. This may not be a problem if this upload is
 targeted at an archive other than Debian's.
See-Also: policy 5.6.14

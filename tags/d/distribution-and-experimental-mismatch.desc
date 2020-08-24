Tag: distribution-and-experimental-mismatch
Severity: error
Check: fields/distribution
Explanation: The <tt>Distribution</tt> in the <tt>.changes</tt> file indicates
 that packages should be installed into a non-experimental distribution
 (suite), but the distribution in the <tt>Changes</tt> field copied from
 <tt>debian/changelog</tt> indicates that experimental was intended.
 .
 This is an easy mistake to make when invoking "sbuild ... foo.dsc".
 Double-check the <tt>-d</tt> option if using sbuild in this way.
See-Also: #542747, #529281

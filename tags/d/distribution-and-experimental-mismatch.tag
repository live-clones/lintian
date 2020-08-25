Tag: distribution-and-experimental-mismatch
Severity: error
Check: fields/distribution
Explanation: The <code>Distribution</code> in the <code>.changes</code> file indicates
 that packages should be installed into a non-experimental distribution
 (suite), but the distribution in the <code>Changes</code> field copied from
 <code>debian/changelog</code> indicates that experimental was intended.
 .
 This is an easy mistake to make when invoking "sbuild ... foo.dsc".
 Double-check the <code>-d</code> option if using sbuild in this way.
See-Also: Bug#542747, Bug#529281

Tag: section-area-mismatch
Severity: error
Check: debian/control
Explanation: The <code>debian/control</code> file places the indicated binary package
 in a different archive area (main, contrib, non-free) than its source
 package or other binary packages built from the same source package. The
 source package and any binary packages it builds must be in the same
 area of the archive, with the single exception that source packages in
 main may also build binary packages in contrib if they build binary
 packages in main.

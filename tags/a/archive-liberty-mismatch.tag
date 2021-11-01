Tag: archive-liberty-mismatch
Severity: error
Check: archive/liberty/mismatch
Renamed-From:
 section-area-mismatch
Explanation: The <code>debian/control</code> file places the named installation
 package in a different archive area (<code>main</code>, <code>contrib</code>,
 <code>non-free</code>) than the source or the other installation packages.
 .
 A source and all installation packages produced from it must be in the
 same archive area, except that sources in <code>main</code> may produce
 installation packages in <code>contrib</code> as long as they also produce
 installation packages in <code>main</code>.

Tag: missing-separator-between-items
Severity: error
Check: debian/control
Explanation: The given field in the <code>debian/control</code> file contains a list
 of items separated by commas and pipes. It appears a separator was
 missed between two items. This can lead to bogus or incomplete
 dependencies, conflicts etc.

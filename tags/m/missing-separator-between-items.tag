Tag: missing-separator-between-items
Severity: error
Check: debian/control/field/relation
Explanation: The named field in the <code>debian/control</code> file is supposed to
 list items that are separated by commas or pipes. A separator seems to be missing.
 .
 Needless to say, it can lead to bogus or incomplete package relationships.

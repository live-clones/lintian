Tag: bad-so-link-within-manual-page
Severity: error
Check: documentation/manual
Explanation: Manual files that use the .so links to include other pages should
 only point to a path relative to the top-level manual hierarchy, e.g.
 .
 <code>.so man3/boo.1.gz</code>

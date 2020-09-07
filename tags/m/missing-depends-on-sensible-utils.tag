Tag: missing-depends-on-sensible-utils
Severity: error
Check: files/contents
Explanation: The listed file appears to use one or more of the binaries
 in <code>sensible-utils</code> but no binary declares a dependency for
 this package.
 .
 As part of the transition to split <code>sensible-utils</code> and
 <code>debianutils</code>, the remaining <code>Depends</code> from
 <code>debianutils</code> was removed in version 4.8.2.
 .
 In most cases you will need to add a <code>Depends</code>,
 <code>Recommends</code>, <code>Pre-Depends</code> or <code>Suggests</code>
 on <code>sensible-utils</code>.

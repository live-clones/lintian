Tag: debian-changelog-line-too-short
Severity: pedantic
Check: debian/changelog
Explanation: The given line of the latest changelog entry appears to contain a
 very terse entry.
 .
 This can make it hard for others to understand the changelog entry.
 Please keep in mind that:
 .
  - It is not uncommon that people read changelog entries that are more
    than a decade old to understand why a change was made or why a
    package works in a specific way.
  - Many users will read the changelog via
    <code>apt-listchanges(1)</code>
  - The information in <code>debian/changelog</code> is permanent.
 .
 Examples for entries that are too short include "dh 11" or simply
 "R³" - these could be expanded to, for example:
 .
  - Switch to debhelper compat 11.
  - Set Rules-Requires-Root: no.

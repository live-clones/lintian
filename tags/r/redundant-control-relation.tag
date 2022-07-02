Tag: redundant-control-relation
Severity: pedantic
Check: debian/control/field/relation
Renamed-From:
 duplicate-in-relation-field
Explanation: The named field in the <code>debian/control</code> file lists
 multiple package relationships when one would be sufficient.
 .
 The less restrictive declaration can be removed. The tools <code>dpkg-source</code>
 and <code>dpkg-gencontrol</code> do that automatically, so it does not affect the
 package generated from this source.

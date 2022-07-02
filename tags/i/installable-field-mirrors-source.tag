Tag: installable-field-mirrors-source
Severity: info
Check: debian/control/field/redundant
Renamed-From:
 binary-control-field-duplicates-source
Explanation: The named field for an installation package in
 <code>debian/control</code> has the same value as the one inherited
 from the source paragraph.
 .
 In the interest of shorter and clearer files, you may wish to take advantage
 of the inheritance rules. This field is redundant.

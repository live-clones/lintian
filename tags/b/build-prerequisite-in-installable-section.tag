Tag: build-prerequisite-in-installable-section
Severity: error
Check: debian/control/field/misplaced
Renamed-From:
 build-info-in-binary-control-file-section
Explanation: The named field appears in an installable section of the
 <code>debian/control</code> file, but the field declares a relationship
 between sources.
 .
 The field should only appear in the source section of the <code>debian/control</code>
 file.
See-Also:
 policy 5.2

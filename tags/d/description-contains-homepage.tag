Tag: description-contains-homepage
Severity: warning
Check: fields/description
Explanation: The extended description contains a "Homepage" pseudo-field
 following the old Developer's Reference recommendation. As of 1.14.6,
 dpkg now supports Homepage as a regular field in
 <code>debian/control</code>. This pseudo-field should be moved from the
 extended description to the fields for the relevant source or binary
 packages.

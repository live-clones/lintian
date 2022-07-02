Tag: invalid-systemd-documentation
Severity: info
Check: systemd
Explanation: The named systemd service file contains a <code>Documentation</code>
 field that is not a URI.
 .
 The field should contain a space-separated list of URIs referencing documentation
 for the unit or its configuration. Accepted are only URIs of the types
 <code>http://</code>, <code>https://</code>, <code>file:</code>, <code>info:</code>,
 <code>man:</code>.
 .
 For more information about the syntax of these URIs, see <code>uri(7)</code>. The URIs
 should be listed in order of relevance, starting with the most relevant. It is a good
 idea to first reference documentation that explains what the unit's purpose is,
 followed by how it is configured, followed by any other related documentation.
 .
 The <code>Documentation</code> key may be specified more than once, in which case the
 specified list of URIs is merged. If the empty string is assigned to this option, the
 list is reset and prior assignments have no effect.
 .
 Documentation for systemd service files can be automatically viewed using
 <code>systemctl help servicename</code> if this field is present.
See-Also:
 systemd.unit(5),
 uri(7)

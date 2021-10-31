Tag: build-info-in-binary-control-file-section
Severity: error
Check: debian/control
Explanation: The <code>debian/control</code> file lists the named fields for
 an installable packages, but the fields declare relationships between sources.
 .
 The fields should appear only in the source section of the
 <code>debian/control</code> file.
See-Also:
 policy 5.2

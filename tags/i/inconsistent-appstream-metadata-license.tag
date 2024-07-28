Tag: inconsistent-appstream-metadata-license
Severity: warning
Check: debian/copyright/dep5
Explanation: The specified AppStream metadata file specifies a
 <code>metadata&lowbar;license</code> field but this does not match
 its entry (possibly via the <code>Files: *</code> stanza) in
 <code>debian/copyright</code>.
See-Also: https://wiki.debian.org/AppStream/Guidelines,
 https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/,
 https://www.freedesktop.org/software/appstream/docs/chap-Metadata.html#tag-metadata_license

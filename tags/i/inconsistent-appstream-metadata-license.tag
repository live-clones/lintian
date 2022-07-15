Tag: inconsistent-appstream-metadata-license
Severity: warning
Check: debian/copyright/dep5
Explanation: The specified AppStream metadata file specifies a
 <code>metadata&lowbar;license</code> field but this does not match the files in
 <code>debian/copyright</code>.
 The upstream metadata_license should be represented in debian/copyright too.
See-Also: https://wiki.debian.org/AppStream/Guidelines,
 https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/

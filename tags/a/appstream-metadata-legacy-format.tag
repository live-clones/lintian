Tag: appstream-metadata-legacy-format
Severity: error
Check: appstream-metadata
See-Also:
 https://wiki.debian.org/AppStream/Guidelines,
 https://www.freedesktop.org/software/appstream/docs/chap-Metadata.html#sect-Metadata-GenericComponent
Explanation: The AppStream metadata contains the obsolete root node
 <code>&lt;application&gt;</code>. It was used in a a legacy format.
 The application metadata for your package should follow the new
 format described on freedesktop.org.
 .
 You can validate draft formats with 'appstreamcli validate'.

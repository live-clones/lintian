Tag: appstream-metadata-legacy-format
Severity: error
Check: appstream-metadata
See-Also: https://wiki.debian.org/AppStream/Guidelines,
 https://www.freedesktop.org/software/appstream/docs/chap-Metadata.html#sect-Metadata-GenericComponent
Explanation: AppStream metadata with obsolete &lt;application&gt; root node found.
 This indicate a legacy format. The metadata should follow the format
 the new outlined on the freedesktop.org homepage.
 .
 It is possible to validate the format using 'appstreamcli validate'.

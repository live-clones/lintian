Tag: upstream-metadata-not-yaml-mapping
Severity: warning
Check: debian/upstream/metadata
See-Also: https://dep-team.pages.debian.net/deps/dep12/
Explanation: The DEP 12 metadata file is not well formed. The document
 level must be a YAML mapping:
 .
     Some-Field: some-value
     Another-Field: another-value
 .
 Sometimes, the fields are mistakenly prefaced with a hyphen, which
 makes them a YAML sequence. In that case, please remove the hyphens.

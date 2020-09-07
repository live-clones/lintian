Tag: changelog-references-temp-security-identifier
Severity: warning
Check: debian/changelog
Explanation: The changelog entry references a temporary security identifier,
 like "TEMP-0000000-2FC21E".
 .
 The TEMP identifier will disappear in the future once a proper CVE
 identifier has been assigned. Therefore it is useless as an
 external reference. Even worse, the identifier is not stable and
 may change even before a CVE is allocated.
 .
 If a CVE has been allocated, please use that instead. Otherwise,
 please replace the TEMP identifier with a short description of the
 issue.
See-Also: Bug#787929, Bug#807892

Tag: team-upload-has-incorrect-version-number
Severity: warning
Check: nmu
Explanation: A team upload (uploading a package from the same team without adding
 oneself as maintainer or uploader) is a maintainer upload: it should not
 get a NMU revision number. Team uploads are recognized by the string
 "team upload" on the first line of the changelog file.

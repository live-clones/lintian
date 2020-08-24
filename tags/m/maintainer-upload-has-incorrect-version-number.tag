Tag: maintainer-upload-has-incorrect-version-number
Severity: warning
Check: nmu
Explanation: A maintainer upload should have a Debian revision without dots.
 Revisions with dots are reserved for Non-Maintainer Uploads (NMUs). If you
 do a maintainer-upload with dots a potential NMU'er has problems choosing a
 correct version number.

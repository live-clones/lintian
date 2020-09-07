Tag: national-encoding
Severity: warning
Check: files/encoding
Renamed-From:
 national-encoding-in-text-file
 debian-changelog-file-uses-obsolete-national-encoding
 debian-control-file-uses-obsolete-national-encoding
 debian-copyright-file-uses-obsolete-national-encoding
 debian-news-file-uses-obsolete-national-encoding
 debian-tests-control-uses-national-encoding
 doc-base-file-uses-obsolete-national-encoding
 national-encoding-in-debconf-template
 national-encoding-in-manpage
Explanation: A file is not valid UTF-8.
 .
 Debian has used UTF-8 for many years. Support for national encodings
 is being phased out. This file probably appears to users in mangled
 characters (also called mojibake).
 .
 Packaging control files must be encoded in valid UTF-8.
 .
 Please convert the file to UTF-8 using <code>iconv</code> or a similar
 tool.

Tag: uses-dpkg-database-directly
Severity: warning
Check: files/contents
Explanation: The listed file or maintainer script appears to access the
 internal database(s) of dpkg.
 .
 The entire dpkg database, its layout and files are an internal
 interface and no program or package should be accessing it, other
 than dpkg itself and the suite of dpkg tools.
 .
 Whilst the files may be editable by an admin, that's a supported (but
 unrecommended) feature reserved for humans and not for automatic tools.
See-Also: https://wiki.debian.org/DpkgConffileHandling

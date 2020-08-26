Tag: insecure-copyright-format-uri
Severity: pedantic
Check: debian/copyright/dep5
See-Also: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Explanation: Format URI of the machine-readable copyright file uses the plain HTTP
 unencrypted transport protocol. Using HTTPS is preferred since policy 4.0.0.
 .
 Please use
 <code>https://www.debian.org/doc/packaging-manuals/copyright-format/*version*/</code>
 as the format URI instead.

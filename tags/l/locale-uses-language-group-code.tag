Tag: locale-uses-language-group-code
Severity: pedantic
Check: files/locales
Explanation: The package appears to ship locales for a language group
 rather than a language as a subdirectory of <code>/usr/share/locale</code>.
 The language codes used in the locale directories are those from the ISO
 639-1 and ISO 639-2 standards, and does not include language group codes
 from the ISO 639-5 standard.
See-Also: Bug#1013946

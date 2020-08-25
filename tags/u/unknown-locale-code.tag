Tag: unknown-locale-code
Severity: warning
Check: files/locales
See-Also: http://www.loc.gov/standards/iso639-2/php/code_list.php
Explanation: The package appears to ship locales for a language but uses an
 unknown locale code as a subdirectory of <code>/usr/share/locale</code>.
 This usually results in users of the intended target language not
 finding the locale. The language codes used in the locale directories
 are those from the ISO 639-1 and ISO 639-2 standards, not those
 usually used as TLDs (which are from the ISO 3166 standard).
 .
 It is possible that the language code was mistyped or incorrectly
 guessed from the language's or country's name.

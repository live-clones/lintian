Tag: incorrect-locale-code
Severity: warning
Check: files/locales
Explanation: The package appears to ship locales for a language but uses an
 incorrect locale code as a subdirectory of <code>/usr/share/locale</code>.
 This usually results in users of the intended target language not
 finding the locale. The language codes used in the locale directories
 are those from the ISO 639-1 and ISO 639-2 standards, not those
 usually used as TLDs (which are from the ISO 3166 standard).
 .
 When both standards define a language code for a given language, the
 ISO 639-1 code should be used (i.e. the two lettered code).
 .
 Lintian only knows about some commonly-mistaken set of incorrect
 locale codes.

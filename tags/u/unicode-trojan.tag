Tag: unicode-trojan
Severity: pedantic
Experimental: yes
Check: files/unicode/trojan
Explanation: The named text file contains a Unicode codepoint that has been
 identified as a potential security risk.
 .
 There are two distinct attack vectors. One is homoglyphs in which text looks
 confusingly similar to what a reader might expects, but is actually different.
 The second is birectional attacks, in which the rendered text hides
 potentially malicious characters.
 .
 Here are the relevant codepoint:
 .
 - ARABIC LETTER MARK (U+061C)
 - LEFT-TO-RIGHT MARK (U+200E)
 - RIGHT-TO-LEFT MARK (U+200F)
 - LEFT-TO-RIGHT EMBEDDING (U+202A)
 - RIGHT-TO-LEFT EMBEDDING (U+202B)
 - POP DIRECTIONAL FORMATTING (U+202C)
 - LEFT-TO-RIGHT OVERRIDE (U+202D)
 - RIGHT-TO-LEFT OVERRIDE (U+202E)
 - LEFT-TO-RIGHT ISOLATE (U+2066)
 - RIGHT-TO-LEFT ISOLATE (U+2067)
 - FIRST STRONG ISOLATE (U+2068)
 - POP DIRECTIONAL ISOLATE (U+2069)
 .
 You can also run a similar check in your shell with that command:
 .
 <code>grep -r $'[\u061C\u200E\u200F\u202A\u202B\u202C\u202D\u202E\u2066\u2067\u2068\u2069]'</code>
See-Also:
 CVE-2021-42694 ("Homoglyph"),
 CVE-2021-42574 ("Bidirectional Attack"),
 https://www.trojansource.codes,
 https://www.trojansource.codes/trojan-source.pdf,
 https://en.wikipedia.org/wiki/Bidirectional_text,
 https://www.ida.org/research-and-publications/publications/all/i/in/initial-analysis-of-underhanded-source-code,
 https://www.ida.org/-/media/feature/publications/i/in/initial-analysis-of-underhanded-source-code/d-13166.ashx

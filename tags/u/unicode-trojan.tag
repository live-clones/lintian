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
 Here are the relevant codepoints:
 .
 - ARABIC LETTER MARK (<code>U+061C</code>)
 - LEFT-TO-RIGHT MARK (<code>U+200E</code>)
 - RIGHT-TO-LEFT MARK (<code>U+200F</code>)
 - LEFT-TO-RIGHT EMBEDDING (<code>U+202A</code>)
 - RIGHT-TO-LEFT EMBEDDING (<code>U+202B</code>)
 - POP DIRECTIONAL FORMATTING (<code>U+202C</code>)
 - LEFT-TO-RIGHT OVERRIDE (<code>U+202D</code>)
 - RIGHT-TO-LEFT OVERRIDE (<code>U+202E</code>)
 - LEFT-TO-RIGHT ISOLATE (<code>U+2066</code>)
 - RIGHT-TO-LEFT ISOLATE (<code>U+2067</code>)
 - FIRST STRONG ISOLATE (<code>U+2068</code>)
 - POP DIRECTIONAL ISOLATE (<code>U+2069</code>)
 .
 You can also run a similar check in your shell with that command:
 .
 <code>grep -r $'[\u061C\u200E\u200F\u202A\u202B\u202C\u202D\u202E\u2066\u2067\u2068\u2069]'</code>
 .
 The registered vulnerabilities are  CVE-2021-42694 ("Homoglyph") and
 CVE-2021-42574 ("Bidirectional Attack").
See-Also:
 https://nvd.nist.gov/vuln/detail/CVE-2021-42694,
 https://nvd.nist.gov/vuln/detail/CVE-2021-42574,
 https://www.trojansource.codes,
 https://www.trojansource.codes/trojan-source.pdf,
 https://en.wikipedia.org/wiki/Bidirectional_text,
 https://www.ida.org/research-and-publications/publications/all/i/in/initial-analysis-of-underhanded-source-code,
 https://www.ida.org/-/media/feature/publications/i/in/initial-analysis-of-underhanded-source-code/d-13166.ashx

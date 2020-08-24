Tag: very-long-line-length-in-source-file
Severity: pedantic
Check: cruft
Explanation: The source file includes a line length that is well beyond
 the normally human made code line length.
 .
 This very long line length does not allow Lintian to do
 correctly some source file checks.
 .
 This line could also be the result of some text injected by
 a computer program, and thus could lead to FTBFS bugs.
 .
 Last but not least, long line in source code could be used
 to obfuscate the source code and to hide stuff like backdoors
 or security problems.
 .
 It could be due to jslint source comments or other build tool
 comments.
 .
 You may report this issue upstream.
Renamed-From:
 insane-line-length-in-source-file

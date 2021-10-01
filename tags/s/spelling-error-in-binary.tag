Tag: spelling-error-in-binary
Severity: info
Check: binaries/spelling
Explanation: Lintian found a spelling error in the given binary. Lintian has a
 list of common misspellings that it looks for. It does not have a
 dictionary like a spelling checker does.
 .
 If the string containing the spelling error is translated with the help
 of gettext or a similar tool, please fix the error in the translations as
 well as the English text to avoid making the translations fuzzy. With
 gettext, for example, this means you should also fix the spelling mistake
 in the corresponding msgids in the &ast;.po files.
 .
 You can often find the word in the source code by running:
 .
  grep -rw &lt;word&gt; &lt;source-tree&gt;
 .
 This tag may produce false positives for words that contain non-ASCII
 characters due to limitations in <code>strings</code>.

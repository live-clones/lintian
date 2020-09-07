Tag: typo-in-manual-page
Severity: info
Check: documentation/manual
Renamed-From: spelling-error-in-manpage
Explanation: Lintian found a spelling error in a manual page. Lintian has a list
 of common misspellings that it looks for. It does not have a
 dictionary like a spelling checker does.
 .
 If the string containing the spelling error is translated with the help
 of gettext (with the help of po4a, for example) or a similar tool,
 please fix the error in the translations as well as the English text to
 avoid making the translations fuzzy. With gettext, for example, this
 means you should also fix the spelling mistake in the corresponding
 msgids in the &ast;.po files.

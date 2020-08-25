Tag: translated-default-field
Severity: warning
Check: debian/po-debconf
Explanation: You should not mark as translatable "Default:" or "DefaultChoice:"
 fields, unless explicitly needed (e.g. default country, default language,
 etc.). If this Default field really should be translated, you should
 explain translators how they should translate it by using comments or
 brackets. For example:
 .
   # Translators: Default language name, but not translated
   &lowbar;Default: English
 .
 Or:
 .
   &lowbar;Default: English[ Default language name, but not translated]
 .
 Note that in the first case, Lintian ignores the comment unless it
 explicitly references translators and it is appears directly before
 the field in question.
See-Also: po-debconf(7), Bug#637881

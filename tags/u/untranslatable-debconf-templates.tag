Tag: untranslatable-debconf-templates
Severity: error
Check: debian/po-debconf
Explanation: This package seems to be using debconf templates, but some
 descriptions are not translatable. You should prepend an underscore
 before every translatable field, as described in po-debconf(7). This
 may mean that translators weren't properly warned about new strings.
 .
 Translators may be notified of changes using podebconf-report-po, for
 example:
 .
  podebconf-report-po --call --withtranslators --deadline="+10 days" \
  --languageteam
 .
 If the field is not intended for users to see, ensure the first line
 of the description contains "for internal use".
See-Also: policy 3.9.1

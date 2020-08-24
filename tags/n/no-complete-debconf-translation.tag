Tag: no-complete-debconf-translation
Severity: info
Check: debian/po-debconf
Explanation: Even though this package provides debconf translation support, there 
 are no translations or none of the translations are complete. This may
 mean that translators weren't properly warned about new strings.
 .
 Translators may be notified of changes using podebconf-report-po, for
 example:
 .
  podebconf-report-po --call --withtranslators --deadline="+10 days" \
  --languageteam
See-Also: devref 6.5.2.2

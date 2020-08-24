Tag: invalid-date-in-debian-changelog
Severity: error
Check: debian/changelog
Explanation: The date format in the latest changelog entry file appears to be invalid.
 .
 Dates should use the following format (compatible and with the same semantics
 of RFC 2822 and RFC 5322):
 .
   day-of-week, dd month yyyy hh:mm:ss +zzzz
 .
 To avoid problems like this, consider using a tool like dch(1) or
 date(1) to generate the date. Example:
 .
   $ date -R -ud '2013-11-05 23:59:59'
   Tue, 05 Nov 2013 23:59:59 +0000
See-Also: policy 4.4

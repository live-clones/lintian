Tag: debian-changelog-has-wrong-day-of-week
Severity: warning
Check: debian/changelog
Explanation: The date in the changelog entry is not consistent with the actual
 day of that week. Either the date is wrong or the day of week is wrong.
 .
 To avoid problems like this, consider using a tool like dch(1) or
 date(1) to generate the date. Example:
 .
   $ date -R -ud '2013-11-05 23:59:59'
   Tue, 05 Nov 2013 23:59:59 +0000
Renamed-From:
 debian-changelog-has-wrong-weekday

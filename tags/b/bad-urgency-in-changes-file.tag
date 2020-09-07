Tag: bad-urgency-in-changes-file
Severity: error
Check: fields/urgency
Explanation: The keyword value of the "Urgency" field in the .changes file is not
 one of the allowed values of low, medium, high, critical, and emergency
 (case-insensitive). This value normally taken from the first line of the
 most recent entry in <code>debian/changelog</code>, which is probably where
 the error is.
See-Also: policy 5.6.17

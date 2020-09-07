Tag: malformed-changes-file
Severity: error
Check: fields/format
Explanation: There is no "Format" field in your .changes file. This probably
 indicates some serious problem with the file. Perhaps it's not actually
 a changes file, or it's not in the proper format, or it's PGP-signed
 twice.
 .
 Since Lintian was unable to parse this .changes file, any further checks
 on it were skipped.
See-Also: policy 5.5

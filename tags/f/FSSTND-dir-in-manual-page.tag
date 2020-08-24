Tag: FSSTND-dir-in-manual-page
Severity: info
Check: documentation/manual
Explanation: The manual page references a directory that is specified
 in the FSSTND but not in the FHS which is used by Debian.
 This can be an indicator of a mismatch of the location of
 files as installed for Debian and as described by the manual page.
 .
 If you have to change file locations to abide by Debian Policy
 please also patch the manual page to mention these new locations.

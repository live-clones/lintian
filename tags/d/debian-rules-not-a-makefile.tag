Tag: debian-rules-not-a-makefile
Severity: error
Check: debian/rules
See-Also: policy 4.9
Explanation: The <code>debian/rules</code> file for this package does not appear to
 be a makefile or does not start with the required line.
 <code>debian/rules</code> must be a valid makefile and must have
 "<code>#!/usr/bin/make -f</code>" as its first line.

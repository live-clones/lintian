Tag: debian-rules-not-a-makefile
Severity: error
Check: debian/rules
See-Also: policy 4.9
Explanation: The <tt>debian/rules</tt> file for this package does not appear to
 be a makefile or does not start with the required line.
 <tt>debian/rules</tt> must be a valid makefile and must have
 "<tt>#!/usr/bin/make -f</tt>" as its first line.

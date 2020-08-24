Tag: legacy-vendorarch-directory
Severity: error
Check: team/pkg-perl/xs-abi
Name-Spaced: yes
Explanation: Since 5.20, Debian perl packages use different directory for placing XS
 libraries, which varies by API version and possibly architecture. Files
 placed in the previously used directory (/usr/lib/perl5) will not be used by
 perl. The build system needs to be fixed to use the value $Config{vendorarch}
 (available from the Config module) instead of hardcoding the directory.
 .
 See Perl Policy 4.1.

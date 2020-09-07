Tag: application-in-library-section
Severity: info
Check: application-not-library
Experimental: yes
Explanation: This package contains a binary in $PATH but is in a section just
 thought for libraries. It likely should be in another section like
 e.g. utils, text, devel, misc, etc., but not in e.g. perl, ruby or
 python.
 .
 People tend to skip these package sections when looking for
 applications in the package list and hence wouldn't notice this
 package.
 .
 In case the program in $PATH is only a helper tool and the package is
 primarily a library, please add a Lintian override for this tag.

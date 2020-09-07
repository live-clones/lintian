Tag: package-contains-no-arch-dependent-files
Severity: info
Check: files/architecture
Experimental: yes
Explanation: The package is not marked architecture all, but all the files it
 ships are installed in /usr/share.
 .
 Most likely this package should be marked architecture all, but there
 is a chance that the package is missing files.
See-Also: policy 5.6.8

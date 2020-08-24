Tag: bin-sbin-mismatch
Severity: info
Check: files/contents
Experimental: yes
Explanation: The package installs a binary under <tt>/usr/sbin</tt> or
 <tt>/sbin</tt> but the specified file or maintainer script appears to
 incorrectly reference it under <tt>/usr/bin</tt> or <tt>/bin</tt>.
 .
 This is likely due to the maintainer identifying that the package
 requires root privileges or similar and thus installing the files to
 the <tt>sbin</tt> variant, but the package has not been comprehensively
 or completely updated to match.
 .
 For ELF files, mismatches could be related to the <tt>SHF_MERGE</tt>
 option to <tt>ld</tt>. The option saves space by providing different
 start indices into the same static location in object files.
 Unfortunately, the sub-string information is lost in that process.

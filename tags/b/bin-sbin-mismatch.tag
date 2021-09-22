Tag: bin-sbin-mismatch
Severity: info
Check: files/contents
Experimental: yes
Explanation: The package installs a binary under <code>/usr/sbin</code> or
 <code>/sbin</code> but the specified file or maintainer script appears to
 incorrectly reference it under <code>/usr/bin</code> or <code>/bin</code>.
 .
 This is likely due to the maintainer identifying that the package
 requires root privileges or similar and thus installing the files to
 the <code>sbin</code> variant, but the package has not been comprehensively
 or completely updated to match.
 .
 For ELF files, false positives could be related to the <code>SHF&lowbar;MERGE</code>
 option to <code>ld</code>. The option saves space by providing different
 start indices into the same static location in object files.
 Unfortunately, the sub-string information is lost in that process.
